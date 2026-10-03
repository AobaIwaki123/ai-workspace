# プロジェクト全体ディレクトリ構成および責務境界設計 (14_project_directory_structure_and_layout.md)

本ドキュメントは、Penlight Quiz v2 における **プロジェクト全体のディレクトリ構造、各パッケージ・モジュールの責務境界、および自動生成成果物の配置規約** を定めた仕様書です。

Standard Go Project Layout およびモダンフロントエンドのベストプラクティスに準拠し、関心の分離（SoC）と AI エージェント協業時のコンテキスト把握容易性を最大化します。

---

## 1. プロジェクト全体ツリー構成

```
space/penlight-v2/
├── AGENTS.md                  # 本スペース固有の規約・方針・スコープ
├── discussion.md              # 議論の方向性、要件定義、ロードマップ、進捗管理
├── adr/                       # 確定したアーキテクチャ意思決定記録 (0001〜)
├── note/                      # 調査・学習・技術設計仕様書 (01〜)
├── assets/                    # 自動生成されたドキュメント資産
│   └── schema/                # 自動生成 ER 図 (er-diagram.md, er-diagram.mermaid)
│
├── backend/                   # [バックエンド] Go 単一バイナリサーバー
│   ├── go.mod
│   ├── go.sum
│   ├── cmd/
│   │   └── server/
│   │       └── main.go        # アプリケーションエントリーポイント
│   ├── pkg/
│   │   ├── model/             # 【正本】ドメインモデル・ID規約 (Single Source of Truth)
│   │   ├── quiz/              # 出題エンジン & Strategy パターン実装
│   │   ├── repository/        # SQLite リポジトリ層 (CRUD & トランザクション)
│   │   ├── auth/              # Google OIDC 認証 & HttpOnly セッション管理
│   │   ├── image/             # WebP 変換・自動リサイズ・EXIF 除去パイプライン
│   │   └── handler/           # HTTP REST API ハンドラ & ルーティング
│   ├── migrations/            # SQLite DDL マイグレーションスクリプト
│   └── embedded/              # フロントエンド静的ビルドを内包する embed.FS
│
├── frontend/                  # [フロントエンド] React 19 / Next.js 静的エクスポート
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   ├── types/
│   │   │   └── generated.ts   # 【自動生成】tygo が Go struct から出力した TypeScript 型
│   │   ├── components/        # 共通 UI コンポーネント (Mantine ベース)
│   │   ├── features/
│   │   │   ├── quiz/          # クイズ画面・正誤演出・ローカル出題純粋関数
│   │   │   ├── offline/       # IndexedDB キャッシュ & Outbox 同期マネージャー
│   │   │   └── admin/         # JSON Schema 駆動の動的マスタ管理画面
│   │   └── sw/                # PWA Service Worker (CacheStorage 管理)
│   └── public/                # ファビコン、PWA manifest.json
│
├── deploy/                    # 自宅 Proxmox k8s デプロイマニフェスト
│   ├── deployment.yaml        # 単一 Pod (Go + Frontend embed) Deployment
│   ├── pvc.yaml               # SQLite 永続化用 PersistentVolumeClaim
│   └── ingress.yaml           # Cloudflare Tunnel / Ingress 設定
│
└── scripts/                   # 開発・自動化・codegen スクリプト
    ├── generate-all.sh        # 全コード生成スクリプト (tygo, OpenAPI, ER図一括生成)
    └── gen-er-diagram.go      # Go struct から Mermaid ER 図を生成するスクリプト
```

---

## 2. 各ディレクトリの責務詳細とデータフロー

### 2.1 `backend/pkg/model/` (正本スキーマ層)
- **役割**: システム全体の最上流となるドメインモデル・識別子定数の定義（Single Source of Truth）。
- **規約**:
  - 外部パッケージへの依存を一切持たない純粋な型定義とする。
  - 構造体タグ（`json`, `db`, `validate`, `tygo`）と GoDoc コメントを集約。
- **含まれるファイル**: `id.go`, `group.go`, `color.go`, `member.go`, `quiz.go`, `user.go`, `answer.go`

### 2.2 `backend/pkg/quiz/` (出題ドメインロジック層)
- **役割**: クイズ設問生成および採点のコアロジック。
- **規約**:
  - `Strategy` インターフェースを定義し、各出題アルゴリズム（`similar_color.go`, `random.go`, `spaced_repetition.go`）を疎結合に分離。
  - CIELAB 色差計算式（$\Delta E$）の実装を内包。

### 2.3 `backend/pkg/repository/` (データ永続化層)
- **役割**: `modernc.org/sqlite` を用いた SQLite への SQL 発行とトランザクション制御。
- **規約**:
  - `PRAGMA journal_mode = WAL;` を前提とした接続プール管理。
  - ドメインモデル（`model.Member` 等）と SQL 行データの相互変換。

### 2.4 `backend/embedded/` (静的アセット埋め込み層)
- **役割**: フロントエンドの静的ビルド成果物（HTML/JS/CSS）を Go バイナリ内に埋め込む。
- **コード例**:
```go
package embedded

import "embed"

//go:embed all:dist
var FrontendFS embed.FS
```

### 2.5 `frontend/src/types/generated.ts` (自動生成型定義)
- **役割**: バックエンドの Go 構造体と 100% 同期した TypeScript 型定義。
- **規約**:
  - **手動編集は厳禁**。修正は必ず `backend/pkg/model/` を変更し `scripts/generate-all.sh` で出力する。

### 2.6 `frontend/src/features/offline/` (Local-First 層)
- **役割**: ライブ会場等のオフライン環境におけるキャッシュ保持と同期。
- **構成**:
  - `db.ts`: IndexedDB 初期化（マスタデータテーブル、Outbox 回答ログテーブル）。
  - `sync.ts`: 通信回復検知と `POST /api/v1/quiz/answers/batch` の自動実行。

---

## 3. 自動生成フローと依存の方向性

システムの依存の矢印は、必ず **Go 構造体（最上流）から下流成果物へ向かう一方向（単方向）** です。

| 生成元 (Source) | 生成ツール | 成果物 (Artifact) | 利用先 (Consumer) |
|---|---|---|---|
| `backend/pkg/model/*.go` | `tygo` | `frontend/src/types/generated.ts` | フロントエンド全体 |
| `backend/pkg/model/*.go` | `scripts/gen-er-diagram.go` | `assets/schema/er-diagram.md` | 人間による設計把握 |
| `backend/pkg/model/*.go` | `invopop/jsonschema` | `api/schema/*.json` | Admin 動的フォーム |
| `backend/cmd/server/main.go` | `swag` | `api/openapi/openapi.yaml` | API 仕様書・Swagger UI |
| `frontend/ (npm run build)` | Go compiler (`embed.FS`) | `cmd/server/server` (単一バイナリ) | k8s 本番 Pod |

---

## 4. 参考文献・標準規約

- [Standard Go Project Layout (GitHub)](https://github.com/golang-standards/project-layout)
- [Next.js Project Structure Guide](https://nextjs.org/docs/app/getting-started/project-structure)
- [Go 1.16 embed Package Documentation](https://pkg.go.dev/embed)
- [Single Source of Truth (Wikipedia)](https://en.wikipedia.org/wiki/Single_source_of_truth)
