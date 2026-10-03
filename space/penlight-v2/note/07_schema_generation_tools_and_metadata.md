# Go スキーマ定義の最大有効活用と自動生成パイプライン (07_schema_generation_tools_and_metadata.md)

本ドキュメントは、**「Go の構造体（Struct）を正本（Single Source of Truth）」** として定義したスキーマを、手作業による二重管理を一切排除して最大限に活用するための自動生成ツールチェーンおよびメタデータ連携案をまとめたものです。

---

## 1. 課題と目的: コードの多重管理とスキーマの乖離を防ぐ

Web 開発において、バックエンドの Go 構造体、フロントエンドの TypeScript 型、データベースの DDL / マイグレーション、API 仕様書（OpenAPI / JSON Schema）、入力バリデーションロジックを手書きで個別に保守すると、必ず不整合が発生します。

本システムでは、**Go 構造体に構造体タグ（Struct Tags）とコメントを付与するだけで、以下の 5 つの派生成果物を完全自動生成** します。

```
                     ┌─── [1. TypeScript 型定義 (.d.ts)] ───► フロントエンド (Next.js)
                     │
                     ├─── [2. JSON Schema / OpenAPI 3.1] ───► API ドキュメント / 外部クライアント
[Go Struct (正本)] ──┼─── [3. SQLite DDL / マイグレーション] ──► データベース初期化
(pkg/model/*.go)     │
                     ├─── [4. ランタイムバリデーション] ──────► リクエスト検証 (validator)
                     │
                     └─── [5. 管理画面フォームメタデータ] ────► 動的 Admin UI 生成
```

---

## 2. 活用ツール選定と自動化パイプライン

| 用途 | 推奨ツール | 概要・選定理由 | 信頼できる情報源 |
|---|---|---|---|
| **TypeScript 型生成** | **`tygo`** | Go AST を直接解析し、Go の struct・定数・コメントから TypeScript の `interface` / `type` を忠実に生成。外部依存なし | [gzuidhof/tygo (GitHub)](https://github.com/gzuidhof/tygo) |
| **JSON Schema 生成** | **`invopop/jsonschema`** | Go struct からリフレクションで最新の JSON Schema (Draft 2020-12) を 1 発生成。カスタムタグや説明文を完全反映 | [invopop/jsonschema (GitHub)](https://github.com/invopop/jsonschema) |
| **OpenAPI 生成** | **`swag`** または **`ogen`** | Go コードのアノテーションから OpenAPI 3.0 / 3.1 仕様書（Swagger UI 含む）を自動生成 | [swaggo/swag (GitHub)](https://github.com/swaggo/swag) |
| **入力バリデーション** | **`go-playground/validator/v10`** | `validate:"required,hexcolor"` などのタグで構造体の正当性をランタイム検証 | [go-playground/validator](https://github.com/go-playground/validator) |
| **SQLite スキーマ生成** | **Go AST 解析スクリプト / `schema-gen`** | Go struct のタグ（`db:"primary_key"`, `db:"not_null"`）から SQLite DDL を自動生成 | 標準ライブラリ (`go/ast`, `go/parser`) |

---

## 3. Go 構造体へのメタデータタグ付与仕様

Go の構造体 1 つに対して、複数の用途（JSON シリアライズ、TS 型生成、DB マッピング、入力検証）のタグを端正に付与します。

### 構造体定義例 (`pkg/model/member.go`)

```go
package model

import "time"

// Member represents an idol member entity.
// @Description アイドルメンバーの基本情報およびペンライトカラー設定
type Member struct {
	// ID is the prefixed UUID v7 surrogate key (e.g. mem_019245a0...)
	ID ID `json:"id" tygo:"type:string" db:"id,pk" validate:"required,prefix=mem"`

	// GroupID points to the parent group ID (e.g. grp_019245a0...)
	GroupID ID `json:"group_id" tygo:"type:string" db:"group_id,fk" validate:"required,prefix=grp"`

	// FamilyName is the member's last name in Kanji (e.g. "加藤")
	FamilyName string `json:"family_name" db:"family_name" validate:"required,max=50"`

	// GivenName is the member's first name in Kanji (e.g. "史帆")
	GivenName string `json:"given_name" db:"given_name" validate:"required,max=50"`

	// Generation represents the joining batch (e.g. 1, 2, 3)
	Generation int `json:"generation" db:"generation" validate:"required,min=1,max=20"`

	// Status represents the current state (active, graduated, hiatus)
	Status MemberStatus `json:"status" db:"status" validate:"required,oneof=active graduated hiatus"`

	// Penlight holds the pair of penlight colors assigned to the member
	Penlight PenlightPair `json:"penlight" db:"-" validate:"required"`

	// ImageKey is the immutable image filename: mem_<uuidv7>.webp
	ImageKey string `json:"image_key" db:"image_key" validate:"required"`

	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}
```

---

## 4. 自動生成ワークフロー (`scripts/generate-all.sh`)

1 コマンドで全レイヤの派生成果物を再同期するスクリプトを整備します。

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> 1. Generating TypeScript definitions via tygo..."
tygo generate

echo "==> 2. Generating OpenAPI 3.1 specification via swag..."
swag init -g cmd/server/main.go -o api/openapi/

echo "==> 3. Generating JSON Schemas for validation..."
go run scripts/gen-jsonschema/main.go

echo "==> 4. Generating SQLite DDL migrations..."
go run scripts/gen-sqlite-ddl/main.go

echo "All schema artifacts successfully generated and synchronized."
```

### 成果物配置構成

```
penlight-v2/
├── backend/
│   ├── pkg/model/           # [正本] Go 構造体定義 (Single Source of Truth)
│   ├── api/openapi/         # [自動生成] OpenAPI 仕様書 (openapi.yaml / openapi.json)
│   └── migrations/          # [自動生成] SQLite DDL (0001_initial_schema.sql)
└── frontend/
    └── src/types/
        └── generated.ts     # [自動生成] tygo が出力した完全同期 TypeScript 型
```

---

## 5. 動的 Admin UI（管理画面）へのメタデータ活用

Go 構造体のスキーマ情報を JSON Schema としてフロントエンド（Next.js）へ提供することにより、**管理画面のフォーム（入力フィールド、型、バリデーション表示）をハードコードせず、スキーマ駆動（Schema-Driven UI）で動的描画** することが可能になります。

- `@rjsf/core` (React JSON Schema Form) や Mantine Form に JSON Schema を渡すだけで、新カラムや新属性が追加されてもフロントエンドのフォーム修正が不要。
- 青葉坂46 等の新グループ追加や新属性（愛称、SNS リンク等）の追加が、Go 構造体の変更と `scripts/generate-all.sh` だけで完結。

---

## 6. 参考文献・公式ドキュメント

- [Go AST (Abstract Syntax Tree) Documentation](https://pkg.go.dev/go/ast)
- [Tygo - Generate Typescript types from Golang source code](https://github.com/gzuidhof/tygo)
- [invopop/jsonschema - Generate JSON Schemas from Go structures](https://github.com/invopop/jsonschema)
- [OpenAPI Specification v3.1.0](https://spec.openapis.org/oas/v3.1.0)
- [go-playground/validator](https://github.com/go-playground/validator)
