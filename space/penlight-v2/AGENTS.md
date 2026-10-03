# 坂道ペンライトクイズ完全刷新 (Penlight Quiz v2) 規約 (AGENTS.md)

このワークスペースは、**坂道グループ（日向坂46、櫻坂46、乃木坂46等）のペンライトカラーを題材としたクイズ・情報管理システム「Penlight Quiz v2」の完全刷新**に関する調査・設計・検証・自動化を推進するための協業領域です。

---

## ディレクトリ構成と役割

```
space/penlight-v2/
├── AGENTS.md                  # 本規約ファイル（スコープ・開発ルール・設計原則）
├── discussion.md              # 議論の方向性、要件定義、進捗管理、アクションアイテム
├── adr/                       # 確定したアーキテクチャ意思決定記録 (0001〜)
├── note/                      # 調査・検証・技術メモ (01〜)
├── assets/                    # 自動生成されたドキュメント資産 (schema/er-diagram.md 等)
│
├── backend/                   # [バックエンド] Go 単一バイナリサーバー
│   ├── go.mod
│   ├── cmd/server/main.go     # サーバーエントリーポイント
│   ├── pkg/
│   │   ├── model/             # 【正本】ドメインモデル・ID規約 (Single Source of Truth)
│   │   ├── quiz/              # 出題エンジン & Strategy パターン実装
│   │   ├── repository/        # SQLite リポジトリ層 (WALモード, CRUD)
│   │   ├── auth/              # Google OIDC 認証 & HttpOnly セッション管理
│   │   ├── image/             # WebP 変換・自動リサイズ・EXIF 除去パイプライン
│   │   └── handler/           # HTTP REST API ハンドラ & ルーティング
│   ├── migrations/            # SQLite DDL マイグレーションスクリプト
│   └── embedded/              # フロントエンド静的ビルドを内包する embed.FS
│
├── frontend/                  # [フロントエンド] React 19 / Next.js 静的エクスポート
│   ├── src/
│   │   ├── types/generated.ts # 【自動生成】tygo が Go struct から出力した TS 型 (編集厳禁)
│   │   ├── components/        # 共通 UI コンポーネント (Mantine ベース)
│   │   ├── features/
│   │   │   ├── quiz/          # クイズ画面・正誤演出・ローカル出題純粋関数
│   │   │   ├── offline/       # IndexedDB キャッシュ & Outbox 同期マネージャー
│   │   │   └── admin/         # JSON Schema 駆動の動的マスタ管理画面
│   │   └── sw/                # PWA Service Worker (CacheStorage 管理)
│   └── public/                # ファビコン、PWA manifest.json
│
├── deploy/                    # 自宅 Proxmox k8s デプロイマニフェスト (Kustomize)
│   ├── base/                  # Deployment (単一Pod), Service, PVC, Ingress (Cloudflare)
│   ├── overlays/              # prod / preview 環境差分
│   └── argocd/                # ArgoCD Application マニフェスト
│
└── scripts/                   # 開発・自動化・codegen スクリプト
    ├── generate-all.sh        # 全コード生成スクリプト (tygo, OpenAPI, ER図一括同期)
    └── gen-er-diagram.go      # Go struct から Mermaid ER 図を生成するスクリプト
```

---

## コア設計原則 (Core Architecture Principles)

1. **Go Code as Schema（Go 構造体を正本とする）**:
   - 会話やドキュメントで合意されたデータモデル・制約は、JSON による二重管理を行わず、Go の構造体（`struct`）を Single Source of Truth（正本）として直接書き下ろします。
   - JSON ファイル等の派生データは、スキーマ確定フェーズまで作成しません。
2. **プレフィックス付き不変サロゲートキー (TypeID Convention)**:
   - 全エンティティにおいて自然キー（名前・略称）の主キー利用を禁止し、`grp_`, `col_`, `mem_`, `quiz_` + UUID v7 によるプレフィックス付きサロゲートキーを採用します（[ADR-0001](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/adr/0001-surrogate-key-typeid-uuidv7.md)）。
   - 画像ファイル名もメンバー名ではなくメンバーID（`mem_<uuidv7>.webp`）で管理し、改名や同姓同名によるファイル名衝突・参照切れを根絶します。
3. **拡張可能グループ設計（Open-Closed 原則）**:
   - 新グループ誕生（例: 青葉坂46）や既存グループの改称・追加に対し、コード変更・再ビルドなしで対応できる動的マスタ構成とします。コード内に特定のグループ名やEnumをハードコードしません。
4. **Pure Go & 超軽量フットプリント**:
   - バックエンドは Go (`modernc.org/sqlite` による Pure Go SQLite) を採用し、Cgo 依存を排除してコンテナサイズ 10〜20MB 級の超軽量・セルフコンテイン稼働を実現します（[ADR-0002](file:///Users/aobaiwaki/ai-workspace/space/penlight-v2/adr/0002-backend-go-architecture.md)）。

---

## 運用・開発ルール

1. **進捗・議論の記録 (`discussion.md`)**:
   - 議論の前提、目的、課題、ネクストアクションを常に最新に保ちます。
2. **知見の蓄積 (`note/`)**:
   - 調査した仕様や技術検証の結果は `note/` に連番付きマークダウンで記録します。
   - 主張の根拠や客観的信頼性を担保するため、公式情報源や一次ソースへのハイパーリンクを明記します。
3. **意思決定の記録 (`adr/`)**:
   - 設計方針やアーキテクチャの選定理由は `adr/` に記録します。
4. **再現性の確保 (`scripts/`, `backend/`)**:
   - 検証用スクリプトや実行手順は `scripts/` 配下にコード化して残し、ドメインロジックは単体テスト（`*_test.go`）で堅牢に保護します。
5. **ドキュメント規約遵守**:
   - 原則として絵文字は使用しません。
   - チャット返答本文への生 Mermaid コードブロック出力は行わず、表（Markdown テーブル）またはドキュメント内へのリンクで表現します。
6. **PR運用ルール**:
   - 手元でのファイルの作成・編集・検証は `main` 上で直接行い、未コミットのまま保持します。ユーザーから「PRを作成してください」と明示的な指示を受けるまでコミット・ブランチ作成は行いません。
