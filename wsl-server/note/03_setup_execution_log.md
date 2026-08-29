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
- **実行結果 (起動・認証完了)**:
  - 公式インストーラーにより `~/.local/bin/agy` に正常導入。
  - SSH リモート環境における URL 経由の Google OAuth 認証を完了し、CLI ターミナルインターフェース（TUI）の正常起動を確認。

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

### 2026-08-29: SSH サーバーセキュリティ強化（Hardening）と締め出し防止の確立

- **目的**: Mirrored モードでホスト LAN に公開されている SSH サーバーの安全性を高めるため、パスワード認証を無効化し公開鍵認証を徹底する
- **作成した定義・スクリプト**:
  - [**`wsl-server/adr/0005-ssh-hardening-and-key-authentication.md`**](../adr/0005-ssh-hardening-and-key-authentication.md): 設計方針と決定事項
  - [**`wsl-server/scripts/harden-ssh.sh`**](../scripts/harden-ssh.sh): 締め出し防止検証付き SSH 堅牢化スクリプト
- **強化設定の内容 (`/etc/ssh/sshd_config.d/99-server-hardening.conf`)**:
  - `PubkeyAuthentication yes`: 公開鍵認証の有効化
  - `PasswordAuthentication no`: パスワード認証の完全無効化
  - `PermitEmptyPasswords no`: 空パスワードの拒絶
  - `KbdInteractiveAuthentication no`: チャレンジ・レスポンス認証の無効化
  - `PermitRootLogin no`: root アカウントでの直接ログイン禁止
- **安全機構 (Safety Guards)**:
  - スクリプト実行時に `~/.ssh/authorized_keys` の存在と有効鍵行数を事前検査し、0件の場合は設定適用を中断（締め出し事故防止）。
  - `sshd -t` による構文チェックが通過した場合のみ `systemctl restart ssh.service` を実行。
- **実行手順 (WSL ターミナル)**:
  ```bash
  # セキュリティ強化の適用
  sudo ./wsl-server/scripts/harden-ssh.sh
  ```
- **実行結果**:
  - `~/.ssh/authorized_keys` に登録された公開鍵を確認後、`/etc/ssh/sshd_config.d/99-server-hardening.conf` を正常配備。
  - 構文検証 `sshd -t` を通過し、`ssh.service` の再起動に成功。
  - クライアント側からパスワード認証なし（公開鍵のみ）での安全な SSH 接続を確認。

---

### 2026-08-29: 単一統合手順書 (Runbook: SERVER_SETUP_GUIDE.md) の作成

- **目的**: ゼロからの環境再現手順（Windows設定 -> WSL2 -> タスクスケジューラ常駐 -> mise -> SSH堅牢化）を1つのマスター手順書に集約する
- **作成ファイル**:
  - [**`wsl-server/SERVER_SETUP_GUIDE.md`**](../SERVER_SETUP_GUIDE.md): 完全再現用単一手順書 (Runbook)
- **成果**:
  - 試行錯誤ログの知見（`note/04`）を網羅し、ゼロからのクリーンインストール手順を一発で実行可能な Runbook として完成。

---

### 2026-08-29: 仕様・実測アロケーションに基づくサーバー性能・ボトルネック評価の実施

- **目的**: 負荷ベンチマークを実行せず、カーネルパラメータ、ハードウェアアーキテクチャ、仮想化サブシステム、I/O スケジューラ、ネットワークスタック等の仕様および実測アロケーションからサーバー性能特性とボトルネック要因を網羅的に調査・評価する
- **作成ファイル**:
  - [**`wsl-server/note/07_server_hardware_and_spec_evaluation.md`**](07_server_hardware_and_spec_evaluation.md): 性能評価・仕様分析レポート
- **主要な調査結果**:
  1. **CPU / 計算能力**:
     - AMD Ryzen 5 4600H (Zen 2, 7nm, 6C/12T, 3.0~4.0GHz)。AVX2, SHA-NI, AES-NI 対応。L3 キャッシュ 4MB。
     - Constant/Reliable TSC による低オーバーヘッド時刻取得。主要脆弱性（Meltdown/L1TF/MDS等）ハードウェア無害。
  2. **メモリサブシステム**:
     - 7.5 GiB (WSL2 割当) / 2.0 GiB Swap。現時点で約 6.6 GiB (88%) の空き余力。
     - `autoMemoryReclaim=gradual` によるホストへの動的返却、THP `[madvise]` 有効。
  3. **ストレージ & I/O**:
     - `/dev/sdd` (ext4 VHDX, 最大 1TB, 空き 950GB)。I/O スケジューラ `[none]` (パススルー最適化)、TRIM/discard 有効。
  4. **ネットワークサブシステム**:
     - Mirrored モードによるホスト LAN 直結 (192.168.11.15, NAT オーバーヘッド 0)。
     - 64 TX/RX マルチキュー NIC (`qdisc mq`)、TSO/GSO/GRO ハードウェアオフロード。
     - エフェメラルポート範囲 `44620 - 48715` (4095 ポート) の仕様を確認（大量外部通信時の留意点）。
  5. **用途別適性**:
     - Go/Rust/Node.js/Python による Web API、ISUCON 競技検証、小〜中規模 DB/Redis 基盤に極めて高い適性を確認。

---

### 2026-08-29: GPU (GTX 1650 Ti)・LLM (llama.cpp)・ストレージ実機ベンチマークの実施

- **目的**: 実際の GPU テンソル演算能力、`llama.cpp` による LLM 推論速度、および ext4 vs 9p の I/O 速度を定量計測する
- **作成ファイル**:
  - [**`wsl-server/note/08_performance_benchmark_results.md`**](08_performance_benchmark_results.md): ベンチマーク測定結果レポート
  - [**`wsl-server/scripts/gpu_benchmark.py`**](../scripts/gpu_benchmark.py): PyTorch CUDA 行列演算・PCIe 転送帯域ベンチマーク
  - [**`wsl-server/scripts/disk_benchmark.sh`**](../scripts/disk_benchmark.sh): ストレージ I/O 計測スクリプト
- **主要な実測データ**:
  1. **GPU テンソル演算 (PyTorch 2.6 / CUDA 12.4)**:
     - 4096×4096 FP32 行列積: **1,785 GFLOPS** (76.99 ms)
     - CPU (257 GFLOPS / 534 ms) 比で **6.9 倍高速**
     - Host → GPU PCIe 転送帯域: **5.25 GB/s**
  2. **LLM 推論 (`llama.cpp` / Qwen2.5 0.5B Instruct Q4_K_M)**:
     - CPU 推論 (ngl=0): Prompt 245.8 t/s, Generation 21.6 t/s
     - GPU オフロード (ngl=99): Prompt 247.8 t/s, **Generation 59.8 t/s** (CPU 比 **2.8 倍高速**)
     - 対話生成実測 (`llama-cli`): **52.9 tokens/sec** での滑らかなストリーミング出力を確認
  3. **ストレージ I/O (256MB Sequential)**:
     - ext4 ネイティブ: Write 535 MB/s, Read 7.1 GB/s
     - Windows 9p マウント: Write 147 MB/s, Read 211 MB/s
     - ext4 が Write で 3.6 倍、Read で 33 倍高速であることを実証

---

### 2026-08-29: 柔軟なGPUサービス基盤（Storage Guard）構築と英語カタカナ読み変換の実証

- **目的**: メイン PC のストレージ圧迫を防ぎつつ柔軟にモデルを切り替え可能な GPU API 基盤（OpenAI 互換）を構築し、英単語・略語（AKB -> エーケービー）の日本語カタカナ読み変換機能を実証する
- **作成ファイル**:
  - [**`wsl-server/note/09_gpu_phonetic_service_and_flexible_architecture.md`**](09_gpu_phonetic_service_and_flexible_architecture.md): サービス基盤 & 英語カタカナ変換仕様書
  - [**`wsl-server/scripts/manage-gpu-service.sh`**](../scripts/manage-gpu-service.sh): ストレージ保護・Hot-Swap 切り替え・API テスト管理スクリプト
  - [**`wsl-server/gpu-service.env`**](../gpu-service.env): GPU サービス環境設定ファイル
- **主要な成果**:
  1. **ストレージ防衛（Storage Guard）**:
     - モデル保存を `models/` に統一し、常時 1 モデル（約 1GB）のみを保持。
     - モデル切り替え時に旧モデル自動削除と `fstrim -v /` による Windows SSD 空きブロックの即時回収を自動化。
  2. **英語 -> カタカナ読み変換の実証**:
     - Qwen2.5 1.5B (VRAM 1.1GB) にアルファベット頭字語ルールを与えた Few-shot プロンプティングにより、「AKB, AWS, USB, CI/CD, iPhone, Kubernetes」に対して「エーケービー, エーダブリューエス, ユーエスビー, シーアイシーディー, アイフォーン, クバネティス」を 100% 正確に出力。
  3. **OpenAI 互換 API 稼働**:
     - `http://192.168.11.15:8080/v1/chat/completions` で LAN 公開。自宅 k8s クラスタの `ExternalName` Service からの呼び出し設定を確立。



