# 総合 API 仕様およびエンドポイント設計書 (10_api_specification_and_endpoints.md)

本ドキュメントは、Penlight Quiz v2 において想定される **全 API エンドポイント（公開用、クイズ、回答履歴、認証、アセット配信、管理画面、システム可観測性）** の設計仕様を網羅したものです。

---

## 1. API 設計原則

1. **RESTful & JSON 原則**: 全てのリクエスト・レスポンスは UTF-8 JSON を基本とし、HTTP ステータスコードを適切に使い分けます。
2. **TypeID パラメータ**: URL パスパラメータおよびリクエストボディの ID には必ずプレフィックス付き ID（`grp_...`, `mem_...` 等）を使用します。
3. **オフライン / Local-First 親和性**: 1 リクエストで全マスタデータを取得できる一括同期エンドポイント（Bootstrap）を提供します。

---

## 2. エンドポイント一覧マトリクス

| メソッド | パス | 認証 | 用途・概要 |
|---|---|---|---|
| **マスタ同期** | | | |
| `GET` | `/api/v1/sync/bootstrap` | 不要 | オフライン動作に必要な全マスタデータ（グループ・カラー・メンバー）の一括取得 |
| `GET` | `/api/v1/groups` | 不要 | グループ一覧取得（表示順ソート） |
| `GET` | `/api/v1/groups/{slug}/members` | 不要 | 特定グループのメンバー一覧（期生・ステータス絞り込み可） |
| `GET` | `/api/v1/colors` | 不要 | カラーマスタ一覧取得（特定グループ所属色＋共通色） |
| **クイズ出題・回答** | | | |
| `GET` | `/api/v1/quiz/generate` | 不要 | クイズ設問の動的生成（Strategy 指定・グループ絞り込み） |
| `POST` | `/api/v1/quiz/answers` | 任意 (ゲスト可) | 1 問ごとの回答送信・即時採点・正答情報返却 |
| `POST` | `/api/v1/quiz/answers/batch` | 任意 (ゲスト可) | オフライン復帰時の回答ログ（複数問）一括バックグラウンド同期 |
| **ユーザー・学習分析** | | | |
| `GET` | `/api/v1/user/me` | 必須 | ログイン中ユーザー情報取得 |
| `GET` | `/api/v1/user/statistics` | 必須 | 総合正答率、グループ別・期生別正答率、平均回答速度、総解答数 |
| `GET` | `/api/v1/user/weaknesses` | 必須 | 直近の誤答データに基づく苦手メンバー・間違えやすいカラー一覧 |
| **Google OIDC 認証** | | | |
| `GET` | `/api/v1/auth/google/login` | 不要 | Google OAuth 2.0 認可フロー開始（リダイレクト） |
| `POST` | `/api/v1/auth/google/callback` | 不要 | 認可コードの検証、ユーザー JIT 作成、HttpOnly セッション Cookie 発行 |
| `POST` | `/api/v1/auth/logout` | 必須 | セッション破棄・Cookie 削除 |
| **画像配信** | | | |
| `GET` | `/images/members/{imageKey}` | 不要 | メンバー写真配信（`Cache-Control: public, max-age=31536000, immutable`） |
| **管理画面 (Admin)** | | | |
| `POST` | `/api/v1/admin/groups` | 管理者 | 新グループ登録（青葉坂46 等） |
| `PUT` | `/api/v1/admin/groups/{id}` | 管理者 | グループ情報更新 |
| `POST` | `/api/v1/admin/colors` | 管理者 | 新色ペンライト登録 |
| `POST` | `/api/v1/admin/members` | 管理者 | 新メンバー登録 |
| `PUT` | `/api/v1/admin/members/{id}` | 管理者 | メンバー情報・ステータス更新 |
| `POST` | `/api/v1/admin/members/upload-image` | 管理者 | 写真アップロード（自動 WebP 変換・リサイズ処理） |
| `GET` | `/api/v1/admin/export` | 管理者 | 全マスタデータの JSON/YAML 一括エクスポート（GitOps シード用） |
| `POST` | `/api/v1/admin/import` | 管理者 | マスタデータの一括インポート |
| **可観測性・システム** | | | |
| `GET` | `/healthz` | 不要 | k8s Liveness / Readiness プローブ |
| `GET` | `/metrics` | 内部限定 | Prometheus 形式の運用メトリクス |

---

## 3. 主要 API のリクエスト / レスポンス詳細仕様

### 3.1 クイズ設問生成 (`GET /api/v1/quiz/generate`)
- **クエリパラメータ**:
  - `group_id`: `grp_...`（特定グループ限定出題、省略時は全グループ）
  - `generation`: `1,2...`（特定期生限定）
  - `strategy`: 出題アルゴリズム指定（`random`, `similar_color`, `spaced_repetition`、デフォルト `similar_color`）
  - `count`: 出題数（1〜10 問、デフォルト 5）
- **レスポンス例 (200 OK)**:
```json
{
  "questions": [
    {
      "id": "quiz_019245a38c9d7a1e8f2b3c4d5e6f7a8b",
      "target_member_id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b",
      "target_member": {
        "id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b",
        "family_name": "加藤",
        "given_name": "史帆",
        "generation": 1,
        "image_key": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b.webp"
      },
      "options": [
        {
          "member_id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b",
          "member_name": "加藤 史帆",
          "left_name": "スカイブルー",
          "left_hex": "#00BFFF",
          "right_name": "ブルー",
          "right_hex": "#0000FF"
        },
        {
          "member_id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8c",
          "member_name": "金村 美玖",
          "left_name": "パステルブルー",
          "left_hex": "#89CFF0",
          "right_name": "イエロー",
          "right_hex": "#FFD700"
        }
      ]
    }
  ]
}
```

### 3.2 回答送信・即時採点 (`POST /api/v1/quiz/answers`)
- **リクエストボディ**:
```json
{
  "quiz_question_id": "quiz_019245a38c9d7a1e8f2b3c4d5e6f7a8b",
  "target_member_id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b",
  "selected_member_id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b",
  "response_time_ms": 1420
}
```
- **レスポンス例 (200 OK)**:
```json
{
  "is_correct": true,
  "correct_member_id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b",
  "explanation": {
    "member_name": "加藤 史帆",
    "penlight_colors": ["スカイブルー", "ブルー"],
    "colors_hex": ["#00BFFF", "#0000FF"]
  }
}
```

### 3.3 オフライン一括同期 (`POST /api/v1/quiz/answers/batch`)
ライブ会場などのオフライン下で蓄積された複数の回答ログを、通信回復時にバックグラウンドで一括登録。
- **リクエストボディ**:
```json
{
  "answers": [
    {
      "quiz_question_id": "quiz_019245a38c9d7a1e8f2b3c4d5e6f7a8b",
      "target_member_id": "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b",
      "is_correct": true,
      "response_time_ms": 1420,
      "answered_at": "2026-10-03T10:15:30Z"
    }
  ]
}
```
- **レスポンス**: `200 OK` (`{"synced_count": 1}`)

---

## 4. 参考文献・公式仕様

- [OpenAPI Specification 3.1.0](https://spec.openapis.org/oas/v3.1.0)
- [RFC 9110 - HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)
