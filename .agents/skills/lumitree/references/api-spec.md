# lumitree API リファレンス

本ドキュメントは、TimeTree 公開カレンダーの正規化プロキシサーバーである `lumitree` (`https://lumitree.aooba.net`) の API 仕様および代表的なカレンダーIDの対応表をまとめたものです。

---

## 1. サーバー情報

* **ベース URL**: `https://lumitree.aooba.net`
* **プロトコル**: HTTPS / REST
* **データ形式**: JSON (`application/json`), iCalendar (`text/calendar`)
* **タイムゾーン**: デフォルトで JST (Asia/Tokyo) 正規化
* **キャッシュ TTL**: In-Memory TTL 10分 (TimeTree 内部 API の負荷軽減)

---

## 2. API エンドポイント

| メソッド | パス | パラメータ | 説明 |
| :--- | :--- | :--- | :--- |
| `GET` | `/healthz` | なし | サーバー死活監視 (Liveness / Readiness) |
| `GET` | `/api/v1/calendars/{id}` | なし | カレンダー基本情報 (ID, タイトル, カバー画像, SNSリンク) |
| `GET` | `/api/v1/calendars/{id}/events` | `year` (任意), `month` (任意), `page` (任意) | カレンダー内のイベント一覧取得 |
| `GET` | `/api/v1/calendars/{id}/events.ics` | なし | iCalendar (.ics) 配信 |

### リクエスト例 (curl)
```bash
# ヘルスチェック
curl -s https://lumitree.aooba.net/healthz

# カレンダーメタデータ取得
curl -s https://lumitree.aooba.net/api/v1/calendars/ilife_official

# イベント一覧取得 (2026年10月)
curl -s "https://lumitree.aooba.net/api/v1/calendars/ilife_official/events?year=2026&month=10"
```

---

## 3. レスポンススキーマ概要

### カレンダーイベント一覧 (`/api/v1/calendars/{id}/events`)
```json
{
  "calendar": {
    "id": "190582",
    "aliasCode": "plus_newidol",
    "title": "ROOKEY ROOKEYS スケジュール",
    "description": "ルキルキちゃん推し活カレンダー",
    "coverImageUrl": "https://...",
    "snsLinks": {
      "twitter": "https://x.com/ROOKEYROOKEYS",
      "instagram": "https://www.instagram.com/rookey_rookeys/"
    }
  },
  "events": [
    {
      "id": "3049952379643484609",
      "title": "稲毛海浜公園プール",
      "description": "クロフェス2026 出演日程決定...",
      "startAt": "2026-10-04T09:00:00+09:00",
      "endAt": "2026-10-04T09:00:00+09:00",
      "allDay": true,
      "timezone": "Asia/Tokyo",
      "location": "稲毛海浜公園プール",
      "url": "https://timetr.ee/p/plus_newidol/3049952379643484609",
      "imageUrls": [
        "https://..."
      ]
    }
  ],
  "pagination": {
    "currentPage": 0,
    "totalPages": 0,
    "totalCount": 0
  }
}
```

---

## 4. 登録済み主要カレンダー ID 一覧

| グループ / 対象 | カレンダー ID (`aliasCode`) | 公式 TimeTree URL |
| :--- | :--- | :--- |
| **iLiFE!** | `ilife_official` | `https://timetreeapp.com/public_calendars/ilife_official` |
| **ROOKEY♡ROOKEYS** | `plus_newidol` | `https://timetreeapp.com/public_calendars/plus_newidol` |
