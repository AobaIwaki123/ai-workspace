# TimeTree 公開カレンダー連携 ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、TimeTree 公開カレンダー（例: `ilife_official` 等）からの情報取得、利用用途（Googleカレンダー連携、通知Bot等）、ロードマップ、進捗を記録・管理します。

---

## 🎯 目的・ゴール

- TimeTree の公開カレンダーからイベント情報を自動的・安定的に抽出する。
- 抽出したイベントデータを活用し、カレンダー同期（iCal / Google Calendar）やリマインダー通知（Discord, Slack, LINE等）を可能にする。

---

## 🗺️ ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **API・アクセス制限の調査** | Webフロントエンド内部APIの特定、ヘッダー/CSRFトークン要件の検証 | ✅ 完了 ([note/01](note/01_public_calendar_api_research.md)) |
| **Step 2** | **取得スクリプトの実装** | Python によるイベント取得・パーススクリプト作成 | ✅ 完了 ([scripts/fetch_events.py](scripts/fetch_events.py)) |
| **Step 3** | **データ形式変換 & 出力対応** | iCal (.ics) 生成、JSON エクスポート、日時フォーマット整形 | 🔄 検討中 |
| **Step 4** | **外部連携・自動化** | 定期実行（GitHub Actions / cron）や通知機能の構築 | 📋 未着手 |

---

## 📝 決定事項 (ADR一覧)

- 現時点で未作成（必要に応じて追加）

---

## 📌 直近のネクストアクション

- [x] TimeTree 公開カレンダー内部APIの仕様特定と疎通確認
- [x] イベント取得スクリプト `fetch_events.py` の作成
- [ ] 取得したイベントを iCalendar (.ics) や CSV 形式に変換する機能の追加
- [ ] 定期フェッチ・差分検知（新規イベント追加時の通知）の設計
