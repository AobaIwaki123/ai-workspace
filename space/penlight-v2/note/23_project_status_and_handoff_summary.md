# プロジェクト現在地および引き継ぎ仕様書 (23_project_status_and_handoff_summary.md)

本ドキュメントは、坂道ペンライトクイズ完全刷新（Penlight Quiz v2）における **これまでの設計・意思決定（ADR）、作成済みコード・スキーマ資産、未着手タスク、および新リポジトリの現状** を整理した引き継ぎ用総合ステータスシートです。

---

## 1. プロジェクト概要

- **目的**: 旧システム（`sakamichi-penlight-quiz`）の構造的負債（BigQuery直結、GCR依存、名前キー破綻、会場での圏外沈黙）を全廃し、自宅 Kubernetes 基盤と Local-First PWA によるゼロコスト・高信頼なシステムとして再構築する。
- **リポジトリ構成**:
  - **設計・正本管理**: `/Users/aobaiwaki/ai-workspace/space/penlight-v2/`
  - **新設プロダクトリポジトリ**: `/Users/aobaiwaki/penlight-v2/`

---

## 2. 確定済みアーキテクチャ意思決定 (ADR-0001 〜 ADR-0016)

全 16 件の ADR が採択済みであり、`adr/README.md` にて公式タグ Allowlist とともに管理されています。

| ADR番号 | 決定タイトル | 確定した仕様・決定内容 |
|---|---|---|
| **ADR-0001** | サロゲートキー (TypeID) 採用 | RFC 9562 UUID v7 にエンティティ識別プレフィックスを付与したサロゲートキーを採用し、自然キーを全廃。 |
| **ADR-0002** | バックエンド言語 Go 採用 | メモリ 15〜30MB 稼働、Cgo-free、コールドスタート 0ms、静的フロントエンド内包 (`embed.FS`) を実現。 |
| **ADR-0003** | 自宅 k8s + ghcr.io 選定 | GCP 課金を廃止し、自宅 Proxmox k8s + Cloudflare Tunnel + GitHub Packages でインフラ費用ゼロ化。 |
| **ADR-0004** | Go 構造体を正本 (SSoT) とする | `backend/pkg/model/` を唯一の正本とし、TS 型、JSON Schema、DDL、ER 図を自動生成（手動二重管理禁止）。 |
| **ADR-0005** | データベース SQLite WAL 採用 | Pure Go ドライバ (`modernc.org/sqlite`) + WAL モードを採用。Litestream で秒単位 S3 差分バックアップ。 |
| **ADR-0006** | 動的ドメインスキーマ構成 | `grp_`, `col_`, `mem_`, `quiz_`, `usr_`, `ans_` による識別。青葉坂46 等の動的追加、同姓同名、左右独立色に対応。 |
| **ADR-0007** | Local-First / PWA オフライン採用 | ライブ会場圏外でも純粋関数でクイズ完結。回答は IndexedDB に退避し回線復旧時に自動バッチ同期。 |
| **ADR-0008** | 画像の永久不変キャッシュ採用 | 写真ファイル名を `mem_<uuidv7>.webp` とし、`Cache-Control: immutable` で CDN キャッシュパージを全廃。 |
| **ADR-0009** | 出題アルゴリズム Strategy 採用 | 完全ランダムを排し、苦手カラーの復習や期生別出題など目的に応じたアルゴリズム分離を採用。 |
| **ADR-0010** | Google OIDC + HttpOnly Cookie | ゲスト利用から段階的オンボーディング、パスワードレス、XSS 耐性のあるセッション管理を採用。 |
| **ADR-0011** | プロジェクトディレクトリ構成 | Standard Go Layout + Next.js 静的エクスポート (`output: 'export'`) を Go 単一バイナリ Pod で配信。 |
| **ADR-0012** | Kubernetes & ArgoCD GitOps | Cloudflare Ingress, cert-manager, 単一 Pod / PVC (Recreate 戦略), ArgoCD 自動同期。 |
| **ADR-0013** | AI 駆動機械的支援ツールチェーン | Knip（デッドコード駆除）、Biome/typos（Rust製超高速検証）、ast-grep（構文監査）による品質担保。 |
| **ADR-0014** | エラー設計 & 最小 Problem Details | 独自エラーの乱立を全廃し、クライアント分岐に必要な最小 6 コード（`INVALID_PARAMS` 等）と RFC 9457 を採用。 |
| **ADR-0015** | 最小環境変数 & 機密分離 | 外部注入が不可欠な 4 変数（`DATA_DIR`, `SESSION_SECRET`, `GOOGLE_CLIENT_*`）のみに絞り込み、内部定数を固定。 |
| **ADR-0016** | ADR ガバナンス & フラット連番管理 | トピック別サブディレクトリのアンチパターンを排除し、単一フラットディレクトリ＋不変連番＋Frontmatter管理を採用。 |

---

## 3. 作成済み成果物一覧（ai-workspace 側）

すべての設計成果物・正本コード・スキーマは `/Users/aobaiwaki/ai-workspace/space/penlight-v2/` 配下に揃っています。

### 3.1 コード・スキーマ・定義ファイル

| ファイルパス | 種別 | 内容・役割 |
|---|---|---|
| `backend/pkg/model/id.go` | Go コード | TypeID (UUID v7) 型定義およびエンティティプレフィックス定数 |
| `backend/pkg/model/group.go` | Go コード | Group エンティティモデル（動的グループ、スラッグ、テーマ色） |
| `backend/pkg/model/color.go` | Go コード | Color エンティティモデル（共通色・グループ色） |
| `backend/pkg/model/member.go` | Go コード | Member エンティティモデル（左右ペンライト色、ステータス、期生、同姓同名ラベル） |
| `backend/pkg/model/quiz.go` | Go コード | QuizQuestion, QuizOption モデル |
| `backend/pkg/model/user.go` | Go コード | User モデル（Google OIDC） |
| `backend/pkg/model/answer.go` | Go コード | AnswerLog モデル（回答ログ） |
| `backend/pkg/model/dto.go` | Go コード | API リクエスト/レスポンス DTO（Bootstrap, SubmitAnswer, BatchSync 等） |
| `backend/pkg/model/error.go` | Go コード | RFC 9457 エラー構造体（`AppError`, `ParamError`）および 6 大エラーコード定数 |
| `backend/pkg/config/config.go` | Go コード | 最小 4 変数の設定構造体ローダーおよび内部定数 |
| `backend/.env.example` | 設定テンプレート | 最小 4 変数のローカル環境変数テンプレート |
| `backend/migrations/000001_init.up.sql` | SQL DDL | SQLite テーブル定義（groups, colors, members, users, answer_logs）、外部キー、複合インデックス |
| `api/openapi.yaml` | OpenAPI 3.1.0 | 全エンドポイント・リクエスト/レスポンス・TypeID バリデーション完全定義 |
| `scripts/gen-er-diagram.go` | 自動化ツール | Go AST を直接解析して Mermaid ER 図を自動生成するスクリプト |
| `assets/schema/er-diagram.md` | ドキュメント | `gen-er-diagram.go` により自動生成された最新 ER 図 |

### 3.2 調査・設計ノート一覧 (`note/`)
- `note/01`: 要件定義とアーキテクチャ壁打ち
- `note/02`: データモデリング・画像管理
- `note/03`: 拡張可能グループ設計と「青葉坂46」対応
- `note/04`: サロゲートキー設計と不変識別子
- `note/05`: スキーマ規約およびドメインモデル仕様書
- `note/06`: システム設計土台・基本方針マトリクス
- `note/07`: Go スキーマ定義自動生成パイプライン
- `note/08`: データベース選定・ユーザー回答履歴・Google認証
- `note/09`: レガシーシステムとの差別化設計観点
- `note/10`: 総合 API 仕様書
- `note/11`: Local-First オフライン PWA 設計
- `note/12`: 画像永久キャッシュ規約 (RFC 8246 immutable)
- `note/13`: クイズ出題アルゴリズム Strategy パターン
- `note/14`: プロジェクトディレクトリ構成および責務境界
- `note/15`: TypeScript AI 駆動開発ツールチェーン
- `note/16`: Kubernetes デプロイ・GitOps パイプライン
- `note/17`: AI 補助ツール・開発支援エコシステム総覧
- `note/18`: Rust 製超高速開発ツール群
- `note/19`: システム全体アーキテクチャ統合仕様書（Mermaid ブロック図・シーケンス図）
- `note/20`: エラー設計および最小 Problem Details 仕様書
- `note/21`: 設定および環境変数仕様書
- `note/22`: ADR 分割方針およびアーキテクチャ決定ガバナンス

---

## 4. 新設リポジトリの現状 (`/Users/aobaiwaki/penlight-v2`)

- **パス**: `/Users/aobaiwaki/penlight-v2`
- **Git 状態**: `main` ブランチ初期化済み、コミット 0 件（untracked）
- **配置済みファイル**:
  - `README.md`: プロダクト概要、主な機能、Mermaid アーキテクチャ図、起動手順
  - `AGENTS.md`: ADR 直結の絶対制約、禁止事項、自己検証コマンド
  - `.vscode/settings.json`: 起動時 README 自動プレビュー設定

---

## 5. 次のステップ（実装フェーズの作業項目）

1. **新リポジトリへの資産移行**:
   - `backend/pkg/model/`、`backend/pkg/config/`、`backend/migrations/`、`api/openapi.yaml` を `/Users/aobaiwaki/penlight-v2/` 配下の同一パスへコピー・配置。
2. **バックエンド実装**:
   - `backend/pkg/repository/`: SQLite WAL 接続および CRUD クエリ実装（`modernc.org/sqlite`）。
   - `backend/cmd/server/main.go`: エントリーポイント、設定ロード、DB マイグレーション実行、HTTP サーバー起動。
   - `backend/pkg/handler/`: OpenAPI 定義に対応するルーティングおよびハンドラー実装。
3. **フロントエンド実装**:
   - `frontend/`: Next.js 15 (App Router, `output: 'export'`) + Mantine v8 + Zustand。
   - PWA Service Worker + IndexedDB によるマスタキャッシュと回答 Outbox キュー。
4. **GitOps & CI/CD**:
   - GitHub Actions ワークフロー（Go test/vet, Biome lint, コンテナビルド & ghcr.io push）。
   - Kubernetes マニフェスト（`deploy/`）。
