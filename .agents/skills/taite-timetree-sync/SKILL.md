---
name: taite-timetree-sync
description: Syncs idol event timetables from TimeTree public calendars via the lumitree API into taite-board schedule.json without overwriting confirmed sessions.
---

# taite-timetree-sync

TimeTree 公開カレンダーの予定を `taite-board` の `data/groups/{group_id}/schedule.json` に同期する。

## 1. 接続先とグループマッピング

- **Endpoint**: `https://lumitree.aooba.net/api/v1/calendars/{calendar_id}/events?year={YYYY}&month={MM}`
- **Calendar ID**:
  - Dolly Kiss (`dollykiss`): `lui_17707`

## 2. 本文デリミタ規則（グループ依存）

本文（`description`）の書式や絵文字はグループ運用によって異なる。テキストのパターンに応じて柔軟に抽出する。

| 抽出対象 | 代表的なデリミタ / キーワード例 |
|---|---|
| 出番時刻 | `🎤`、`出番:`、`LIVE:`、`出演:` |
| 特典会時刻 | `📸`、`特典会:`、`物販:`、`チェキ会:` |
| 会場名 | `📍`、`場所:`、`会場:` |
| 入場特典 | `🎁`、`特典:`、`動員特典:` (※絵文字は除去・テキスト化) |
| チケットURL | `🎫`、`チケット:`、`URL:` |

※ 時刻が未定の場合は `start_time: "--:--"`、`end_time: "--:--"` とする。

## 3. マージ・保護原則（必須）

1. **確定枠の非破壊**: 既存の `schedule.json` で既に時刻（`--:--` 以外）、会場、特典、チケットURLが確定している公演は上書きしない。未定枠（`--:--`）または新規公演のみ補完・追加する。
2. **スキーマ準拠**: 必須フィールド（`schema_version: 1`, `group_id`, `generated_at`, `timezone: "Asia/Tokyo"`）を維持し、`taite validate` を通過させる。
3. **絵文字排除**: `admission_bonus` などのフィールドに絵文字を含めない（`➕` -> `+` 等に正規化）。

## 4. 出力先

- `space/taite-board/data/groups/{group_id}/schedule.json`
