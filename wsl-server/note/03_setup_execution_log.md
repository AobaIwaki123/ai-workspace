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

### 2026-08-29: WSL 再起動後の自動復旧不可（外部からの SSH 接続不可）課題

- **目的**: OS 再起動後の WSL インスタンス自動復旧および外部 SSH 接続性の確保
- **発生した事象**:
  - `do-release-upgrade` 完了に伴う再起動（Restart）後、WSL が停止状態（または未起動状態）となり、外部から SSH 接続できない（自動復旧しない）事象を確認。
- **原因**:
  - WSL2 はデフォルトでオンデマンド起動（Windows 側でコマンドやターミナルが叩かれた時に起動）するため、再起動後は Windows 側で `wsl.exe` を叩くトリガーが存在しない限り起動せず、外部からの着信パケットだけでは起動しない。
- **解決策 (Windows タスクスケジューラによるブート時/ログオン時自動起動)**:
  - Windows 側で以下の PowerShell（管理者）コマンドを実行し、タスクスケジューラに「Windows 起動時/ログオン時にバックグラウンドで WSL を自動起動・常駐させるタスク」を登録する。
  ```powershell
  # タスク名: WSL-AutoStart
  # 動作: ログオン時に非表示で wsl.exe をバックグラウンド起動し常駐維持
  $Action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d Ubuntu-24.04 -u root --exec sleep infinity"
  $Trigger = New-ScheduledTaskTrigger -AtLogOn
  $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
  $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
  Register-ScheduledTask -TaskName "WSL-AutoStart" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
  ```
- **検証**:
  - タスクの手動実行テスト:
    ```powershell
    Start-ScheduledTask -TaskName "WSL-AutoStart"
    ```
  - WSL がバックグラウンドで立ち上がり、クライアントから即座に SSH 接続できることを確認。

---

---

### [次回作業枠]: コンテナ基盤 (Docker / Docker Compose) の導入

- **目的**: 
- **実行したコマンド**:
- **メモ**:
