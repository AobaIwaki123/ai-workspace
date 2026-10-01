# TimeTree → iCal リンク変換UI 論点整理

セッション日時: 2026-08-22

---

## 発端・やりたいこと

`https://timetreeapp.com/public_calendars/<alias_code>` のような TimeTree 公開カレンダー URL を貼り付けると、
Google カレンダー等に登録できる **iCal/Webcal 購読リンクをワンクリックで生成・コピーできる UI** が欲しい。

---

## 結論：変換ロジックはサーバーレスで完結できる

lumitree の OpenAPI 仕様 (`api/openapi.yaml`) に以下のエンドポイントが定義されている。

```
GET /api/v1/calendars/{calendarId}/events.ics
```

TimeTree URL から iCal URL への変換は **純粋な URL 文字列操作のみ**：

```
入力: https://timetreeapp.com/public_calendars/ilife_official
                                                ↓ alias_code を抽出
出力: webcal://<lumitree-host>/api/v1/calendars/ilife_official/events.ics
```

JavaScript/TypeScript のフロントエンドのみで完結可能。バックエンド新規実装不要。

---

## 未解決の論点（次セッションへの引き継ぎ）

### 1. lumitree のホスト名はどこか？

| ケース | lumitree-host の扱い |
|--------|----------------------|
| 自宅 k8s で稼働中 | 固定ホスト名をUIにハードコード or 設定 |
| まだどこにも立てていない | UIと同時にデプロイ計画が必要 |
| ユーザーが自前で立てる前提 | UI でホスト名も入力させる設計 |

→ **lumitree が現在どこかで動いているか確認すること。**

### 2. どのリポジトリに UI を置くか？

- このセッションでは「別 repo を作る」という方向で話が進んだが、**ai-workspace 上での作業は適切でない**と判断してセッションを変えることにした。
- 候補:
  - `lumitree` リポジトリ内にフロントエンドディレクトリを追加（`ui/` や `web/`）
  - 新規リポジトリ（`lumitree-ui` 等）を別途作成

### 3. ホスティング先

- GitHub Pages（静的サイト、無料、CI/CD 簡単）
- Vercel / Cloudflare Pages（同様に無料枠あり）
- `lumitree` サーバーと同居（同一ホストで配信）

---

## 参考：lumitree リポジトリ情報

| 項目 | 内容 |
|------|------|
| リポジトリ | https://github.com/AobaIwaki123/lumitree |
| 言語 | Go |
| iCal エンドポイント | `GET /api/v1/calendars/{calendarId}/events.ics` |
| JSON エンドポイント | `GET /api/v1/calendars/{calendarId}/events` |
| カレンダー情報取得 | `GET /api/v1/calendars/{calendarId}` |
| OpenAPI 仕様 | `api/openapi.yaml` |
| calendarId の取得方法 | TimeTree URL 末尾の文字列（例: `ilife_official`） |

---

## 次セッションでやること

1. lumitree の稼働状況を確認（どこで動いているか、ホスト名）
2. UIの配置リポジトリを決定（lumitree 内 or 新規 repo）
3. ホスティング先を決定
4. 実装開始（HTML入力欄 → alias_code 抽出 → webcal URL 生成 → コピーボタン）
