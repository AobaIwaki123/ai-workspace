# OpenAI Codex CLI ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、OpenAI Codex CLI に関する目的、ロードマップ、議論の経緯、進捗を記録・管理します。

---

## 目的・ゴール

- OpenAI Codex CLI の仕様、コマンド体系、利用制限（レートリミット構造）の把握とノウハウ蓄積
- 効率的な開発運用のためのトークン節約プラクティスおよび設定の体系化

---

## ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **利用量・制限仕様の調査** | `/usage` と `/status` の違い、5時間・週間・月次リミット構造の整理 | 完了 ([note/01_usage_and_rate_limits.md](file:///Users/aobaiwaki/ai-workspace/space/codex/note/01_usage_and_rate_limits.md)) |
| **Step 2** | **運用・設定の最適化** | トークン節約運用 (`/compact`, `/new`) および config.toml 設定の調査 | 次回着手 |
| **Step 3** | **自動化・検証** | 連携スクリプトや CI でのヘッドレス実行ノウハウの確立 | 未着手 |

---

## 調査メモ一覧

- [01_usage_and_rate_limits.md](file:///Users/aobaiwaki/ai-workspace/space/codex/note/01_usage_and_rate_limits.md): Codex CLI 利用状況確認コマンド (/usage vs /status) とレートリミット構造仕様

---

## 決定事項 (ADR一覧)

- なし

---

## 直近のネクストアクション

- [ ] 設定ファイル (`~/.codex/config.toml`) やモデル切り替え (`/model`) の運用仕様調査

