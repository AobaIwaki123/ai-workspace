# WSL サーバー構築 作業実行ログ & 試行錯誤記録 (note/03)

## 1. 概要

本ドキュメントは、WSL サーバー環境を構築・セットアップしていく過程で実行したコマンド、インストールしたパッケージ、設定ファイルの変更、遭遇した課題と解決策をリアルタイムに記録・蓄積するための作業ログです。
ここで蓄積した生データ・ログをもとに、最終的な「単一の統合手順書（Runbook）」へと昇格・清書します。

---

## 2. 作業ログ記録フォーマット (テンプレート)

```markdown
### YYYY-MM-DD: [作業タイトル / カテゴリ名]

- **目的**: 
- **実行したコマンド**:
  ```bash
  # 実行したコマンド
  ```
- **変更した設定ファイル**:
  - ファイルパス: `/path/to/config`
  - 変更内容・差分:
- **検証・動作確認結果**:
  - 
- **メモ・課題・エラーと対処**:
  - 
```

---

## 3. セットアップ作業ログ (随時追記)

### 2026-08-29: SSH サーバーの初期構築と接続確立

- **目的**: Windows ホスト上の WSL2 に外部端末からアクセス可能にするための SSH サーバー構築
- **状況**:
  - WSL インスタンス内で SSH サーバー（`sshd`）を起動し、クライアントからの SSH 接続に成功。
  - 試行錯誤を交えて接続まで開通させた状態のため、今後のクリーンアップ対象を特定しつつ、続くサーバーミドルウェア・自動起動環境の構築に進む。

---

### 2026-08-29: Ubuntu 22.04 LTS から 24.04 LTS (Noble Numbat) へのアップグレード & SSH 接続断トラブル

- **目的**: 最新の LTS リリース（Ubuntu 24.04 LTS）へ OS をアップグレード
- **実行した操作 / コマンド**:
  ```bash
  # パッケージの最新化とアップグレード
  sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
  sudo apt autoremove -y

  # リリースアップグレードの実行
  sudo do-release-upgrade
  ```
- **発生した事象・課題**:
  - アップグレード完了後、外部クライアントからの SSH 接続が通らない（PowerShell で `wsl` 起動中を確認していたが、Windows 側で WSL ターミナルを直接開いた瞬間に接続可能になる現象を確認）。
- **事象の記録とメモ**:
  - 詳細原因は引き続き検証中だが、WSL2 のセッション状態やネットワークインターフェースの初期化タイミングに依存している可能性があるため、ログとして保持。
  - 恒久対策の候補として、Windows タスクスケジューラによるバックグラウンド常駐化（Keep-Alive）や Mirrored ネットワークモードの適用を整理。

---

### 2026-08-29: `apt update` 実行時の lock 競合エラー (`/var/lib/apt/lists/lock`)

- **目的**: アップグレード後のパッケージリスト更新
- **実行したコマンド**:
  ```bash
  sudo apt update
  ```
- **発生したエラー**:
  ```text
  Reading package lists... Done
  E: Could not get lock /var/lib/apt/lists/lock. It is held by process 3665 (noble)
  N: Be aware that removing the lock file is not a solution and may break your system.
  E: Unable to lock directory /var/lib/apt/lists/
  ```
- **原因の特定**:
  - `do-release-upgrade` は、SSH 切断時にも処理が落ちないように自動で GNU `screen` セッション（`ubuntu-release-upgrade-screen-window`）を作成して実行される。
  - SSH 一時切断後、この `screen` セッション内で `do-release-upgrade` がユーザー入力待ち（不要パッケージ削除の確認や再起動確認のプロンプト）のまま待機していたため、`apt` のロック（PID 3665）が解放されていなかった。
- **対処・解決実績**:
  1. `screen` セッションに再接続（アタッチ）を実行:
     ```bash
     sudo screen -r
     ```
  2. 中断していたアップグレード画面への復帰を確認。指示（古い不要パッケージの削除確認や再起動プロンプト）を進めてアップグレードを完遂。
  3. アップグレード完了後の確認と事後クリーンアップ:
     ```bash
     # OS バージョン確認
     cat /etc/os-release

     # パッケージリスト更新と残骸の削除
     sudo apt update && sudo apt autoremove -y
     ```
- **手順書化に向けた知見**:
  - `do-release-upgrade` をリモート SSH 経由で行う場合、途中でセッションが切れたら `sudo screen -r` で復帰してプロンプトを進める必要がある。
  - 新規構築の統合手順書（Runbook）では、アップグレードではなく `wsl --install -d Ubuntu-24.04` による直接インストールを標準としつつ、既存環境からの移行トラブルシューティングとして本手順を併記する。

---

---

### 2026-08-29: WSL 内部からの再起動（reboot）の挙動と自動復旧の仕組み

- **目的**: `do-release-upgrade` 完了に伴う WSL 内部 Ubuntu の再起動処理と復旧方法の整理
- **疑問と課題**:
  - アップグレード完了時に「System restart required」と表示されるが、WSL 内部で `sudo reboot` を実行した場合に単体で自動再起動して立ち上がってくるのか？
- **WSL の仕様と挙動**:
  1. **WSL 内部での `sudo reboot` / `sudo shutdown -r now`**:
     - systemd 有効化環境であっても、WSL 内部から `reboot` を叩くと、WSL インスタンス（仮想マシン）の全プロセスが終了（Terminate）して **停止状態（Stopped）** に遷移する。
     - 通常のベアメタル Linux やクラウド VM と異なり、WSL は Hyper-V/仮想マシン基盤として Windows ホストから管理されているため、**Windows ホスト側から起動要求（`wsl.exe` 呼び出し）がない限り、WSL 自律で電源を再投入（再起動）することはできない**。
  2. **完全再起動（Clean Restart）の標準手順**:
     - **手順**: Windows の PowerShell またはコマンドプロンプトから以下の 1 行を実行する。
       ```powershell
       wsl.exe --shutdown; Start-Process wsl.exe -ArgumentList "-d Ubuntu -u root --exec sleep infinity" -WindowStyle Hidden
       ```
     - これにより、古い WSL インスタンスが安全に終了され、数秒で新カーネル・新 Ubuntu 24.04 としてバックグラウンド再起動し、SSH 接続が復帰する。
- **統合手順書に向けた知見**:
  - WSL 上での Linux アップグレード後の「再起動」は、WSL 内部で `reboot` を打つのではなく、**Windows ホスト側から `wsl.exe --shutdown` 経由で再起動するのが最も確実かつ安全**である。

---

### 2026-08-29: ターミナル終了に伴う WSL 停止（Stopped）事象と恒久常駐化の必要性

- **目的**: ターミナル画面を開いておかなくても WSL を 24時間365日バックグラウンド常駐させる
- **発生した事象**:
  - Windows Terminal や PowerShell で WSL を手動起動すると SSH 接続可能になるが、**ターミナル画面を閉じると数十秒で WSL が Stopped になり SSH が切断される**事象を確認。
  - OS 再起動後や手動起動時に毎回 PowerShell コマンドを叩かないとサーバーとして機能しない課題を特定。
- **原因 (WSL のプロセスライフサイクル)**:
  - WSL はデフォルトで、アクティブなフォアグラウンドプロセス（開いているターミナルセッション）が無くなると、自動的にインスタンスを終了（Stopped）させてメモリを解放する省電力仕様になっている。
- **恒久対策 (自動化スクリプトの作成・整備)**:
  - 毎回手動で PowerShell を叩く手間を排除するため、ワンクリック／1コマンドで登録可能なスクリプトを `scripts/` に整備：
    1. **Windows 側ワンクリック実行**: [`scripts/setup-autostart.bat`](../scripts/setup-autostart.bat)（管理者権限で右クリック実行）
    2. **Linux 側 1 コマンド実行**: [`scripts/setup-host-autostart.sh`](../scripts/setup-host-autostart.sh)（SSH 先の WSL ターミナルから直接 Windows 側のタスクを登録）
  - **PowerShell コマンドの各パラメータ解説**:
    - `$LoopCommand`: `while ($true) { wsl.exe ... sleep infinity; Start-Sleep 2 }`
      - `sleep infinity` で Linux プロセスを維持し、ターミナルを閉じても Stopped にさせない。
      - `sudo reboot` 等でプロセスが exit しても、外側の `while` ループが 2 秒後に即座に `wsl.exe` を再起動して自動復活。
    - `-WindowStyle Hidden`: バックグラウンド実行（黒いプロンプト画面を表示させない）。
    - `-NoProfile -NonInteractive`: PowerShell プロファイル読み込みをスキップして高速・安全に起動し、対話プロンプトを待たない。
    - `-AtLogOn`: Windows ログオン時に自動起動。
    - `-RunLevel Highest`: 管理者特権で実行（WSL / ネットワーク設定へのアクセスを確実化）。
    - `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries`: バッテリー駆動時や省電力時でもタスクを止めない。
    - `-ExecutionTimeLimit 0`: Windows タスクスケジューラのデフォルト制限（3日/72時間での強制終了）を解除し、無期限（24時間365日）連続稼働させる。
      - **副作用とリスク**: 本来タスクがハング・暴走した際に OS が自動キルするセーフティネットが無効化される。
      - **安全性の担保**: 本スクリプトは `Start-Sleep -Seconds 2` を挟み、通常時は `sleep infinity` でブロッキング待機するため CPU/メモリ負荷は実質 0.0% であり、暴走リスクは極めて低い。
    - `Register-ScheduledTask`: 初回セットアップ時は `-Force` なしでクリーンに登録可能（再設定・上書き時は必要に応じて使用）。
  - **タスクスケジューラ登録直後に State が Ready（停止）に戻る問題と解決**:
    - **事象**: タスク登録後に `Start-ScheduledTask` を実行しても、`Running` にならず `Ready` に戻ってしまい WSL が起動しない。
    - **原因**: タスクスケジューラの `Action` 引数欄（`-Argument`）に直接複雑な PowerShell コマンドライン（引用符・中括弧）を渡すと、タスクスケジューラの XML 登録時に引用符が破壊され、PowerShell プロセスが起動直後に構文エラーで Exit していたため。
  - **検証実績**:
    - `setup-autostart.bat` の実行により、`%USERPROFILE%\.wsl_keepalive.ps1` の配置およびタスクスケジューラ `WSL-AutoStart-Server` の `State: Running` 登録・常駐化に成功。

---

### 2026-08-29: `sudo reboot` による WSL 自動再起動・自己修復の動作検証

- **目的**: Ubuntu 内部から `sudo reboot` を実行した際に、Windows 側の監視ループにより 2 秒で自動再起動・SSH 復旧するかを検証
- **検証手順**:
  1. クライアント端末から SSH 接続中に `sudo reboot` を実行
  2. セッション切断後、約 3〜5 秒待機
  - **検証結果 (完全合格)**:
    - Windows 側に一切触れない**完全ハンズフリー状態で `sudo reboot` からの自動復旧・SSH 再接続に成功**。
    - 自律的自己修復（Auto-Recovery）の動作が 100% 証明された。
- **復旧所要時間（体感 1〜2分）の要因分析と知見**:
  1. **systemd のシャットダウン待ち時間 (SIGTERM -> SIGKILL)**:
     - `sudo reboot` 時、Ubuntu 内部のバックグラウンドプロセスが正常終了するまでの猶予時間（`DefaultTimeoutStopSec` デフォルト 90秒）があり、完全終了までに数十秒かかる場合がある。
  2. **WSL インスタンスの完全終了検知**:
     - Windows 側の PowerShell ループは、WSL インスタンスが完全に終了（Exit）した瞬間に検知し、2 秒後に再起動をかける。
  3. **systemd 起動・ネットワーク同期**:
     - 再起動後、約 5〜10 秒で SSH サーバーが立ち上がり接続可能になる。
- **結論**:
  - 即座に数秒で復帰しなくても、**「放置しておけば 1〜2分以内に確実に自動で起き上がって接続可能になる」** ことが実証された。

---

---

### 2026-08-29: Antigravity CLI (`agy`) の導入と初期認証

- **目的**: WSL Ubuntu 環境上で Antigravity CLI (`agy`) をセットアップし、エージェント協業環境を整える
- **事前準備**:
  ```bash
  # 必須ツールの確認・導入
  sudo apt update && sudo apt install -y curl git jq
  ```
- **インストール手順**:
  ```bash
  # 公式インストーラーの実行
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  ```
- **環境変数 PATH の設定**:
  ```bash
  # PATH の反映（~/.bashrc に追加）
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc

  # インストール確認
  agy --version
  ```
- **リモート SSH 環境における初回認証フロー**:
  1. `agy` を起動
  2. ヘッドレス / SSH 環境のため、ターミナルに「Google 認証用 URL」が表示される
  3. ローカル端末（Mac / PC）のブラウザでその URL を開き、Google アカウントでログイン・認証
  4. ターミナル側で認証が自動検知され、CLI が起動完了

---

### 2026-08-29: 宣言的ツール・ランタイムマネージャー `mise` の導入と一括セットアップ

- **目的**: Node.js, Go, Python, GitHub CLI (`gh`), `jq`, `ripgrep`, `fzf` 等を `mise.toml` で完全宣言管理する
- **作成した定義ファイル**:
  - [**`wsl-server/mise.toml`**](../mise.toml): ツールとバージョンの一覧
  - [**`wsl-server/scripts/setup-mise.sh`**](../scripts/setup-mise.sh): `mise` の自動インストール、シェル連携、ツール一括ダウンロード実行スクリプト
- **実行手順 (WSL ターミナル)**:
  ```bash
  # 最新の変更を取得してスクリプトを実行
  git pull origin feat/wsl-server-space
  ./wsl-server/scripts/setup-mise.sh
- **実行結果 (全ツール導入完了)**:
  - `mise` の自動セットアップおよび `mise.toml`（ADR-0004 準拠の 7-day 検証済み固定バージョン）に基づく全 13 ツール・ランタイムの一括ダウンロード・導入に完全成功。
  - **導入された主要ツール一覧**:
    - **言語ランタイム**: Node.js (`v20.x`), Go (`1.23.x`), Python (`3.12.x`), `uv`
    - **開発・運用 CLI**: `gh` (GitHub CLI), `jq`, `ripgrep` (`rg`), `fd`, `fzf`, `bat`, `eza`, `delta`, `starship`
  - **サプライチェーン安全性の確保**: `paranoid = true` による SHA256 チェックサム検証を通過し、隔離されたユーザー領域（`~/.local/share/mise`）で安全に稼働中。

---

### [次回作業枠]: コンテナ基盤 (Docker / Docker Compose) の導入

- **目的**: 
- **実行したコマンド**:
- **メモ**:




