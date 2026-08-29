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
  - アップグレード完了後、外部クライアントからの SSH 接続が拒否される（またはタイムアウト/認証失敗する）事象が発生。
- **特定された根本原因**:
  - Ubuntu 24.04 へのアップグレードに伴い SSH の起動方式が `ssh.socket` に切り替わったが、この `ssh.socket` が `inactive (dead)` の状態になっていたため、SSH ポート（22）の待ち受けが停止していた。
- **復旧・恒久対応コマンド**:
  ```bash
  # 1. 不安定な ssh.socket を停止・無効化
  sudo systemctl stop ssh.socket
  sudo systemctl disable ssh.socket

  # 2. 従来の常駐型 ssh.service を有効化・起動
  sudo systemctl enable --now ssh.service

  # 3. 稼働状態およびポート待ち受けの確認
  sudo systemctl status ssh
  sudo ss -tulpn | grep :22
  ```
- **統合手順書に向けた知見**:
  - Ubuntu 24.04 では `ssh.socket` ではなく `ssh.service` を明示的に有効化（`sudo systemctl disable --now ssh.socket && sudo systemctl enable --now ssh.service`）する手順を Runbook に標準組み込みとする。

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
