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
- **対処・解決手順**:
  1. `screen` セッションに再接続（アタッチ）:
     ```bash
     sudo screen -r
     # または
     sudo screen -x ubuntu-release-upgrade-screen-window
     ```
  2. 画面上の指示（不要パッケージの削除 `y` / 再起動確認等）に回答し、アップグレードを最後まで正常完了させる。
  3. アップグレード完了後、自動的に `screen` が終了し `apt` のロックが解放される。
  4. 確認:
     ```bash
     sudo apt update
     ```
- **手順書化に向けた知見**:
  - `do-release-upgrade` を SSH 経由で行う場合、途中でセッションが切れたら `sudo screen -r` で復帰して完了させる必要がある。

---

### [次回作業枠]: 基本開発ツール & パッケージの導入

- **目的**: 
- **実行したコマンド**:
- **メモ**:

---

### [次回作業枠]: Windows 起動時の WSL / サービス常駐・自動起動設定

- **目的**: 
- **実行したコマンド**:
- **メモ**:

---

### [次回作業枠]: コンテナ基盤 (Docker / Docker Compose) の導入

- **目的**: 
- **実行したコマンド**:
- **メモ**:
