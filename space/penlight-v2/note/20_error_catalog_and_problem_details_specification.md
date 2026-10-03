# エラー設計およびレスポンス仕様書 (20_error_catalog_and_problem_details_specification.md)

本ドキュメントは、エラーコードの過剰な細分化（YAGNI 違反）を排除し、**クライアントが実際に受信して画面遷移やトースト表示などの挙動を変える必要がある最小限のエラー体系** を定めた仕様書です。

---

## 1. エラー設計原則: HTTP ステータス重視と最小コード化

1. **HTTP ステータスの意味を尊重する**:
   - HTTP ステータスコード（400, 401, 403, 404, 422, 500）で表現できる意味を、独自のエラーコードで重複して細切れに再定義しません。
2. **クライアントの分岐に必要なものだけをコード化する**:
   - エラーコードを分ける基準は唯一、**「クライアント（フロントエンド）がそのコードを見てロジックやUIの分岐を行うかどうか」** です。
   - クライアントにとって「見つからなかった」という事実は同じであるにもかかわらず、`RES_GROUP_NOT_FOUND`、`RES_MEMBER_NOT_FOUND`、`RES_COLOR_NOT_FOUND` とコードを乱立させることを禁止します（404 `NOT_FOUND` で統一）。
3. **詳細なフィールドエラーは `invalid_params` に委譲する**:
   - 「TypeIDが不正」「必須漏れ」「画像が大きすぎる」などの入力エラーを個別のエラーコードに分けず、400 `INVALID_PARAMS` の内包配列として表現します。

---

## 2. 最小エラーレスポンス形式 (RFC 9457 最小構成)

```json
{
  "title": "Bad Request",
  "status": 400,
  "code": "INVALID_PARAMS",
  "detail": "Validation failed for request parameters",
  "invalid_params": [
    {
      "field": "member_id",
      "message": "Must be a valid TypeID starting with 'mem_'"
    }
  ]
}
```

- `title`: HTTP ステータスの標準テキスト（例: "Bad Request", "Not Found"）
- `status`: HTTP ステータスコード数値
- `code`: クライアント分岐用の一意コード（後述の 6 つのみ）
- `detail`: 人間向けの要約メッセージ
- `invalid_params` (任意): フォームバリデーション等のフィールド別エラー詳細

---

## 3. 実用エラーコード一覧（必要最小限の 6 つのみ）

本システムでバックエンドが返却し、クライアントがハンドリングするエラーコードは **以下の 6 つのみ** です。

| HTTP Status | エラーコード (`code`) | 発生条件 | クライアント（フロントエンド）の挙動・分岐 |
|---|---|---|---|
| **400** | `INVALID_PARAMS` | パラメータ形式不正、必須漏れ、ファイル形式/サイズ超過 | 該当フォーム項目にインラインエラーを表示、またはトースト通知 |
| **401** | `UNAUTHORIZED` | 未ログイン、セッション切れ、無効な Cookie | ログインモーダルを表示、またはログイン画面へリダイレクト |
| **403** | `FORBIDDEN` | 一般ユーザーが `/admin` 系 API にアクセス | 「管理者権限がありません」の警告画面を表示 |
| **404** | `NOT_FOUND` | 指定された ID（グループ、メンバー等）が存在しない | 「データが見つかりません」画面を表示、またはマスタ再同期 |
| **422** | `INSUFFICIENT_MEMBERS` | 絞り込み条件（期生等）の現役メンバーが 4 人未満で 4 択クイズを生成できない | **（ドメイン特有）** ユーザーに「全期生を対象にしてください」と条件緩和を提案 |
| **500** | `INTERNAL_ERROR` | サーバーの予期せぬ例外、DB 接続失敗 | 「サーバーで問題が発生しました」トーストを表示（自動で指数バックオフ 1 回再試行） |

---

## 4. 削減・全廃した過剰なエラーコード

| 以前の過剰コード | 全廃理由と統合先 |
|---|---|
| `VAL_INVALID_TYPEID`, `VAL_MISSING_REQUIRED_FIELD`, `IMG_FILE_SIZE_EXCEEDED`, `IMG_UNSUPPORTED_FORMAT` | クライアントはどれも「入力値を直してください」と表示するだけ。すべて 400 `INVALID_PARAMS` の `invalid_params` 配列に集約。 |
| `RES_GROUP_NOT_FOUND`, `RES_MEMBER_NOT_FOUND`, `RES_COLOR_NOT_FOUND` | リソース名ごとにコードを分ける意味がない。404 `NOT_FOUND` で統一。 |
| `AUTH_SESSION_EXPIRED`, `AUTH_INVALID_GOOGLE_TOKEN` | セッションが無効であることに変わりはなく、クライアントの対応は「再ログイン」一択。401 `UNAUTHORIZED` に集約。 |
| `SYS_DATABASE_UNAVAILABLE`, `SYS_SERVICE_MAINTENANCE` | 外部向けには 500 `INTERNAL_ERROR`（または 503）で十分。内部のログにだけ原因を記録する。 |

---

## 5. Go バックエンド実装のシンプル化

Go 側で複雑なエラー型階層を作らず、標準的な 1 つの `AppError` 構造体とヘルパー関数だけで完結します。

```go
package apperror

import "net/http"

type ParamError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

type AppError struct {
	Status        int          `json:"status"`
	Code          string       `json:"code"`
	Title         string       `json:"title"`
	Detail        string       `json:"detail"`
	InvalidParams []ParamError `json:"invalid_params,omitempty"`
}

func (e *AppError) Error() string {
	return e.Detail
}

// 頻出ヘルパー
func InvalidParams(params ...ParamError) *AppError {
	return &AppError{
		Status:        http.StatusBadRequest,
		Code:          "INVALID_PARAMS",
		Title:         "Bad Request",
		Detail:        "Validation failed",
		InvalidParams: params,
	}
}

func NotFound(detail string) *AppError {
	return &AppError{
		Status: http.StatusNotFound,
		Code:   "NOT_FOUND",
		Title:  "Not Found",
		Detail: detail,
	}
}

func Unauthorized() *AppError {
	return &AppError{
		Status: http.StatusUnauthorized,
		Code:   "UNAUTHORIZED",
		Title:  "Unauthorized",
		Detail: "Authentication required",
	}
}

func InsufficientMembers(detail string) *AppError {
	return &AppError{
		Status: http.StatusUnprocessableEntity,
		Code:   "INSUFFICIENT_MEMBERS",
		Title:  "Unprocessable Entity",
		Detail: detail,
	}
}
```
