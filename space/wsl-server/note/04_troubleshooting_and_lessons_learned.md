# WSL サーバー構築 トラブルシューティング知見集 & 落とし穴まとめ (note/04)

## 1. 概要

本ドキュメントは、Windows 11 上で WSL2（Ubuntu 24.04 LTS）を用いた常時稼働サーバー環境を構築・自動化する過程で遭遇した**すべてのトラブル、失敗原因、および確立された解決策・ベストプラクティス**を体系的に整理した知見集です。
今後のミス再発防止および最終的な統合手順書（Runbook）作成の設計根拠として活用します。

---

## 2. 知見・落とし穴マトリクス

| No. | カテゴリ | 遭遇した事象・エラー | 根本原因 | 確立された解決策・設計 |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **SSH / Ubuntu 24.04** | アップグレード後に SSH 接続不能 (`Connection refused`) | Ubuntu 24.04 で `ssh.socket` がデフォルト化され、inactive 状態で停止していた | `systemctl disable --now ssh.socket && systemctl enable --now ssh.service` で常駐型サービスに戻す |
| **2** | **APT / アップグレード** | `apt update` 時に `/var/lib/apt/lists/lock` 保持エラー | `do-release-upgrade` が一時切断時に GNU `screen` セッション内に取り残され入力待ちだった | `sudo screen -r` でアタッチしてプロンプトを進めて完了させる |
| **3** | **Linux 内部再起動** | Ubuntu 内部で `sudo reboot` すると二度と立ち上がらない | WSL は仮想基盤のため、Linux 内部からの reboot は「停止(Stopped)」となり自動復電しない | Windows 側で PowerShell 監視ループ（`while true`）を動かし、プロセス終了を検知して2秒で再起動 |
| **4** | **プロセス寿命 (WSL)** | ターミナル画面を閉じると WSL が Stopped になる | WSL2 はフォアグラウンドプロセスが無くなると数十秒で省電力自動終了する仕様 | バックグラウンドで `wsl.exe ... sleep infinity` を常駐させてセッションを永続維持 |
| **5** | **ネットワーク構成** | NAT モードで IP 変動やポート転送のサスペンドが発生 | WSL2 の仮想サブネットと Windows ホストの二重管理によるもの | Windows 11 の **Mirrored ネットワークモード (`networkingMode=mirrored`)** を採用 (ADR-0001) |
| **6** | **バッチ文字コード** | `.bat` ファイル実行時に日本語が文字化けする | Windows `cmd.exe` のデフォルト文字コードが Shift-JIS (CP932) のため | スクリプト冒頭に `chcp 65001 >nul` を入れ、出力はクリーンなテキストで統一 |
| **7** | **PowerShell 互換性** | `New-ScheduledTaskSettingsSet` でパラメータ型エラー落ち | `-ExecutionTimeLimit 0`（数値は不可、TimeSpanが必要）やバージョン非互換 | 最低限の共通パラメータに絞り、シンプルかつ堅牢な構文を採用 |
| **8** | **タスクスケジューラ引数** | タスク登録後に `State: Ready` に戻り WSL が起動しない | `-Argument` に直接長いスクリプト文字列を渡すと XML 登録時にクォートが破壊され即死する | スクリプトを `%USERPROFILE%\.wsl_keepalive.ps1` にファイル配置し、`-File` で呼ぶ構成に分離 |
| **9** | **バッチ内エスケープ崩れ** | 1ファイル完結バッチ内で引用符や特殊文字が壊れる | `cmd.exe` のパーサーが `^` や `"` や `()` を誤解釈して PowerShell に渡る | バッチが `%TEMP%` にクリーンな `.ps1` を自己生成して実行する「自己生成パターン」で根絶 |
| **10** | **PowerShell Set-Content** | `Set-Content -Encoding` パラメータがバージョンにより非互換で落ちる | PowerShell 5.1/7.x で `-Encoding` の受け入れ値（UTF8, utf8NoBOM 等）や存在差異がある | PowerShell の `Set-Content` を使わず、バッチ自身が `(echo ... ) > %USERPROFILE%\.wsl_keepalive.ps1` で直接書き出す方式を採用 |
| **11** | **mise ツール名指定** | `ubi:cli/cli` 等でアーカイブ内バイナリ名不一致エラー | `ubi` バックエンドは非推奨となり、リポジトリ名と実行ファイル名（`gh` vs `cli`）の齟齬が起きる | `gh = "latest"`, `ripgrep = "latest"`, `starship = "latest"` など mise 公式標準ネイティブ名で宣言する |
| **12** | **~/.local/bin PATH未反映** | `agy` や `mise` 実行時に `command not found` | `~/.local/bin` が現在のセッションの `$PATH` に未反映（ログインシェル再起動待ち） | `~/.bashrc` / `~/.zshrc` に `export PATH="$HOME/.local/bin:$PATH"` を永続化し `source` を促す |
| **13** | **SSH 締め出し (Lockout)** | パスワード認証無効化後に接続不能になる | クライアントの公開鍵が `~/.ssh/authorized_keys` に登録される前にパスワード遮断した | スクリプト内で `authorized_keys` の存在と有効鍵行数を事前検証し、0件時は遮断処理をブロック |
| **14** | **SSH 設定競合・上書き** | `apt upgrade openssh-server` 時に設定が衝突・初期化 | `/etc/ssh/sshd_config` を直接書き換えていたためパッケージ更新プロンプトが発生 | `/etc/ssh/sshd_config.d/99-server-hardening.conf` による非破壊ドロップイン管理を採用 |
| **15** | **sshd 構文エラー事故** | 設定リロード後に `sshd` が停止・再接続不能 | 設定パラメータのタイポや非互換構文でデーモンがクラッシュ | 反映直前に `sshd -t` による構文検証を必須化し、失敗時は即座に自動ロールバック |
| **16** | **PIN未入力での常駐起動** | Windows再起動後にPIN入力前でもWSLが起動するか | Windows 10/11 の ARSO (Automatic Restart Sign-On) により事前ログオンが走る | `AtLogOn` トリガー設定で、物理的なPIN入力不要で完全ハンズフリー自動起動が成立 |

---

## 3. 各トラブルの詳細解説と再発防止策

### 3.1 Ubuntu 24.04 の SSH Socket Activation 問題
- **詳細**: Ubuntu 24.04 (Noble) では、systemd の socket activation（`ssh.socket`）がデフォルトで導入された。しかし、WSL 環境やリモートサーバー用途では、ソケットのバインド失敗やポート変更設定（`/etc/ssh/sshd_config`）の不一致が多発する。
- **再発防止策**: 新規セットアップ時は、常に以下の 2 行を実行して常駐型 `ssh.service` に固定する。
  ```bash
  sudo systemctl disable --now ssh.socket
  sudo systemctl enable --now ssh.service
  ```

---

### 3.2 WSL 内部再起動（reboot）と監視ループ（Keep-Alive Watcher）
- **詳細**: クラウド VM や物理 PC と違い、WSL は Windows の `wsl.exe` が親プロセスとして起動・管理している。Ubuntu 内部で `sudo reboot` やクラッシュが発生すると、WSL 仮想マシン全体が `Stopped` に遷移し、外部からの通信だけでは起動しない。
- **再発防止策**: Windows 側のタスクスケジューラで以下の監視ループを常駐させる。
  ```powershell
  while ($true) {
      wsl.exe -u root --exec /bin/sleep infinity
      Start-Sleep -Seconds 2
  }
  ```
  `sleep infinity` が exit しても、外側の `while` ループが 2 秒後に即座に `wsl.exe` を再実行し、完全自律復旧する。

---

### 3.3 タスクスケジューラ登録スクリプトの黄金パターン（Golden Rule）
- **詳細**: Windows のタスクスケジューラに PowerShell スクリプトを登録する際、コマンドライン引数（`-Argument`）に直接コード文字列を埋め込むと、Windows のバージョンやエスケープの違いで失敗（即座に `Ready` で終了）しやすい。
- **再発防止策**:
  1. 実行したい PowerShell コードは、必ず物理ファイル（例: `%USERPROFILE%\.wsl_keepalive.ps1`）として配置する。
  2. タスクスケジューラのアクションには以下のように `-File` で渡す：
     ```powershell
     New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`""
     ```
  3. バッチファイル（`.bat`）から配布する場合は、バッチ自身が一時 `.ps1` を作成して実行する「自己生成方式」を用いる。

---

### 3.4 SSH セキュリティ強化と安全なドロップイン管理
- **詳細**: サーバーをホストネットワーク（Mirrored Mode）で外部公開する際、ブルートフォース攻撃対策としてパスワード認証を無効化する必要がある。しかし、安易に `/etc/ssh/sshd_config` を編集すると、(1) 締め出し事故、(2) パッケージ更新時の設定衝突、(3) 構文エラーによるデーモン停止のリスクがある。
- **再発防止策**:
  1. `/etc/ssh/sshd_config.d/99-server-hardening.conf` に設定を隔離。
  2. 反映前に `grep -v '^#' ~/.ssh/authorized_keys` で公開鍵存在を確認。
  3. 反映前に `sshd -t` を実行し、0 以外の終了コード時はファイルを削除してロールバック。

---

### 3.5 Windows 再起動時における ARSO と完全ハンズフリー起動
- **詳細**: Windows Update やホスト再起動後、画面がロック状態（PIN 入力画面）のままでも、Windows の **ARSO（Automatic Restart Sign-On / サインイン情報の自動再開）** 機能によって内部セッションが自動初期化される。
- **動作メカニズム**:
  1. OS 起動時に Windows が前回のユーザーアカウントをバックグラウンド初期化。
  2. タスクスケジューラの `AtLogOn` トリガーが自動発火。
  3. `WSL-AutoStart-Server` が実行され、WSL2 インスタンスおよび `ssh.service` が起動。
  4. **人間がキーボードを一切触らずとも、外部から `ssh wsl` で接続可能になる**。
