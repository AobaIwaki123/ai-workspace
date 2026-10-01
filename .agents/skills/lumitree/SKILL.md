---
name: lumitree
description: Fetches, normalizes, and formats public calendar events (e.g., idol live schedules, event listings) from the lumitree TimeTree proxy API (https://lumitree.aooba.net). Use this skill when asked to check idol schedules, search upcoming live events from TimeTree public calendars, or extract event data by calendar ID (e.g. ilife_official, plus_newidol).
---

# lumitree Skill

TimeTree 公開カレンダーの正規化プロキシサーバーである `lumitree` (`https://lumitree.aooba.net`) を使用して、指定したカレンダーのイベント情報（ライブ情報、スケジュール、出演日程など）を取得・抽出・整形するためのスキルです。

---

## 1. カレンダー ID の特定

イベントを取得するには、対象の TimeTree 公開カレンダー ID (`aliasCode`) が必要です。

1. **既知のカレンダー**:
   - [references/api-spec.md](./references/api-spec.md) に登録されている主要カレンダー ID を確認します。
   - 例: iLiFE! -> `ilife_official`
   - 例: ROOKEY ROOKEYS -> `plus_newidol`
2. **新規カレンダーの調査**:
   - Web 検索で対象グループやイベントの公式 TimeTree カレンダーを探します。
   - URL 形式: `https://timetreeapp.com/public_calendars/<calendar_id>` の `<calendar_id>` 部分を抽出します。

---

## 2. イベント取得スクリプト (`fetch-events.py`)

同梱の Python スクリプト [scripts/fetch-events.py](./scripts/fetch-events.py) を使用して、カレンダーからイベントを取得・整形します。

### 基本コマンド

```bash
# Markdown 形式で当月の直近イベントを取得 (デフォルト)
./.agents/skills/lumitree/scripts/fetch-events.py <calendar_id>

# 件数を絞り込み (例: 直近 5 件)
./.agents/skills/lumitree/scripts/fetch-events.py <calendar_id> --limit 5

# 当日以降の直近イベントのみを抽出
./.agents/skills/lumitree/scripts/fetch-events.py <calendar_id> --upcoming-only

# 年月を指定して取得
./.agents/skills/lumitree/scripts/fetch-events.py <calendar_id> --year 2026 --month 10

# プレーンテキスト形式で出力 (チャット通知や要約用途)
./.agents/skills/lumitree/scripts/fetch-events.py <calendar_id> --format text

# JSON 形式で生データを取得 (他スクリプトやツールとの連携用)
./.agents/skills/lumitree/scripts/fetch-events.py <calendar_id> --format json
```

---

## 3. Direct API エンドポイント

スクリプトを使わず直接 curl や HTTP リクエストで取得することも可能です。

- **カレンダー情報**:
  `GET https://lumitree.aooba.net/api/v1/calendars/{calendar_id}`
- **イベント一覧**:
  `GET https://lumitree.aooba.net/api/v1/calendars/{calendar_id}/events?year={YYYY}&month={MM}`
- **iCalendar (.ics)**:
  `GET https://lumitree.aooba.net/api/v1/calendars/{calendar_id}/events.ics`

詳細なスキーマ定義および仕様は [references/api-spec.md](./references/api-spec.md) を参照してください。

---

## 4. 実行後・出力結果の検証

取得したデータを提示・加工する際は以下の点を確認します:

1. **取得ステータス**: スクリプト終了コードが 0 であり、エラーメッセージが標準エラーに出力されていないこと。
2. **日付・時刻の整合性**: イベントの開始日時 (`startAt`) が JST タイムゾーンで正しくパースされていること。
3. **リンクの有効性**: イベント詳細 URL (`url`) や SNS リンクが正規の URL 形式であること。
