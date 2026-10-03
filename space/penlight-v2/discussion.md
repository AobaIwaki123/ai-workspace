# 坂道ペンライトクイズ完全刷新 (Penlight Quiz v2) ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、坂道グループ（日向坂46、櫻坂46、乃木坂46等）のペンライトカラーを題材としたクイズ・情報管理システム「Penlight Quiz v2」の完全刷新に関する目的、要件定義、ロードマップ、壁打ちの経緯、進捗を記録・管理します。

---

## 目的・ゴール

1. **レガシー負債の完全解消**:
   - 旧実装（`sakamichi-penlight-quiz`）における設計の歪み、不完全なデータパイプライン、GCR 等の旧式インフラ依存を全廃し、現代的スタックでゼロベース再構築。
2. **堅牢なデータモデルと自動更新**:
   - メンバーの加入・卒業・ペンライトカラー変更に柔軟に追従できるスキーマとマスタデータ管理。
3. **拡張性とマルチプラットフォーム展開**:
   - Web アプリケーション（モダンフロントエンド）、API / MCP サーバー連携（Discord Bot からの出題や AI エージェント連携）を視野に入れた疎結合アーキテクチャ。
4. **クリーンなインフラ・CI/CD**:
   - GitHub Actions、コンテナ化、最小限のクラウド/自宅基盤によるコスト効率と可観測性の両立。

---

## ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Step 1** | **レガシー課題分析 & 業務要件定義** | 旧実装の課題（不完全な点）の洗い出し、新要件・ユースケース策定 | 完了 ([note/01](./note/01_requirements_and_architecture_brainstorming.md)) |
| **Step 2** | **データモデリング & カラーパレット設計** | グループ・期生・メンバー・カラー定義、画像管理、フィルタリングヘルパー共通化設計 | 完了 ([note/02](./note/02_data_modeling_and_helper_architecture.md), [note/04](./note/04_surrogate_key_and_identifier_design.md)) |
| **Step 3** | **システムアーキテクチャ選定** | フロントエンド/バックエンド/DB/ホスティング方針の決定 (ADR) | 完了 ([ADR-0001](./adr/0001-surrogate-key-typeid-uuidv7.md), [ADR-0002](./adr/0002-backend-go-architecture.md)) |
| **Step 4** | **プロトタイプ実装 & クイズロジック検証** | 基本出題アルゴリズム、正誤判定、スコアリング実装 | 未着手 |
| **Step 5** | **CI/CD & インフラ自動化** | GitHub Actions、デプロイパイプライン構築 | 未着手 |

---

## 調査・学習ノート一覧 (note/)

- [**01. Penlight Quiz v2 要件定義とアーキテクチャ壁打ちノート**](./note/01_requirements_and_architecture_brainstorming.md): 5つのコア要件分析、Next.js/BigQuery直結からの脱却、TypeScript完結 vs Go比較、SQLite適合性
- [**02. データモデリング・画像管理・フィルタリング共通化設計**](./note/02_data_modeling_and_helper_architecture.md): 先行型定義（Member/PenlightColor）、純粋関数フィルタリングヘルパー、画像登録UIとJSON/GitOps連動
- [**03. 拡張可能グループ設計と「青葉坂46」対応アーキテクチャ**](./note/03_extensible_group_architecture_and_aobazaka.md): グループID/カラー定義の動的マスター化、Open-Closed原則、管理UIからのノンストップ追加仕様
- [**04. サロゲートキー設計と不変識別子アーキテクチャ**](./note/04_surrogate_key_and_identifier_design.md): 同姓同名・改名に耐えうるプレフィックス付き不変ID（mem_...）、名前依存完全排除
- [**05. スキーマ規約およびドメインモデル仕様書**](./note/05_schema_and_domain_specification.md): Go構造体を正本とした全体統括Prefix Rule・データスキーマ・バリデーション規約
- [**06. システム設計土台・基本方針マトリクス**](./note/06_architectural_foundations.md): 6つの観点（デプロイ先、データ保持、追加容易性、開発容易性、マスタ拡張性、スキーマ把握性）の比較と確定方針
- [**07. Go スキーマ定義の最大有効活用と自動生成パイプライン**](./note/07_schema_generation_tools_and_metadata.md): tygo / JSON Schema / OpenAPI 3.1 / バリデータ / 動的Admin UI連携設計
- [**08. データベース選定精査・ユーザー回答履歴蓄積・Google認証設計**](./note/08_database_selection_and_user_history_auth.md): SQLite最新動向比較（DuckDB/libSQL等）、ユーザー正答・誤答ログ蓄積モデル、Google OIDC認証連携方針
- [**09. レガシーシステムと決定的な差をつける差別化設計観点**](./note/09_differentiating_architectural_advantages.md): 会場オフラインPWA耐性、不変WebP永久キャッシュ、類似色ひっかけ・忘却曲線出題、全画面サイリウムエミュレーター
- [**10. 総合 API 仕様およびエンドポイント設計書**](./note/10_api_specification_and_endpoints.md): 公開マスタ同期、クイズ出題・即時採点、オフライン一括同期、Google認証、管理画面CRUD、Prometheus監視
- [**11. ライブ会場での完全動作を保証する Local-First / オフライン PWA 設計**](./note/11_local_first_offline_pwa_architecture.md): Service Worker、CacheStorage、IndexedDB Outbox キュー、クライアント純粋関数による完全ローカル出題
- [**12. 画像の永久キャッシュ規約とアセット最適化パイプライン**](./note/12_immutable_image_caching_and_asset_pipeline.md): RFC 8246 immutable、サロゲートキー連動WebP、ゼロパージ運用、自動リサイズ
- [**13. クイズ出題アルゴリズムの Strategy パターン設計**](./note/13_quiz_generation_strategy_pattern.md): CIELAB色差Delta E類似色ひっかけ、忘却曲線復習、同期生限定、プラグイン拡張可能なStrategy設計
- [**14. プロジェクト全体ディレクトリ構成および責務境界設計**](./note/14_project_directory_structure_and_layout.md): Standard Go Layout、フロントエンド配置、自動生成成果物フロー、k8sマニフェスト構成
- [**15. TypeScript 最新 AI 駆動開発ツールチェーンと実践エコシステム**](./note/15_typescript_ai_agent_driven_development.md): Knip（AIデッドコード駆除）、ts-morph（AST決定論的リファクタリング）、ts-pattern（網羅的状態マッチング）、BAML（型安全AIプロンプト）、Biome超高速自己修正ループ
- [**16. Kubernetes デプロイ・GitOps パイプライン設計**](./note/16_k8s_deployment_and_gitops_pipeline.md): journee/k8sの知見継承（Cloudflare Tunnel, cert-manager, ArgoCD）、ghcr.io化、単一Pod/PVC構成
- [**17. AI 補助ツールおよび開発支援エコシステム総覧**](./note/17_ai_developer_assistive_tooling_ecosystem.md): 7大カテゴリ（コンテキスト最適化、コード衛生、ASTリライト、コード生成、高速静的検証、LLM統合、ミューテーション検証）のツール比較マトリクス
- [**18. Rust 製超高速開発ツール群および AI 支援エコシステム調査**](./note/18_rust_based_dev_tools_and_ai_assistants.md): Biome, Oxlint, ast-grep, typos, mise, Repomix, sqlc 等の機械的支援ツール群
- [**19. システム全体アーキテクチャ統合仕様書**](./note/19_system_architecture_overview.md): クライアント(PWA)、エッジ(Cloudflare)、k8s/Go単一バイナリ、SQLite WAL、データフローを網羅した全体構成図・テーブル
- [**20. エラーコード体系および Problem Details 設計仕様書**](./note/20_error_catalog_and_problem_details_specification.md): RFC 9457準拠、機械可読な一意エラーコード（SYS, VAL, AUTH, RES, QUIZ, IMG）、クライアント自律修復・リトライポリシー規約
- [**21. 設定および環境変数仕様書**](./note/21_configuration_and_environment_variables_specification.md): Twelve-Factor準拠、Go構造体マッピング、起動時フェイルファスト検証、k8s ConfigMap/Secret注入方針
- [**22. ADR 分割方針およびアーキテクチャ決定ガバナンスのベストプラクティス**](./note/22_adr_partitioning_and_governance_best_practices.md): トピック別サブディレクトリの破綻理由、フラット不変連番＋Frontmatter多面管理、システムスコープ分割、AI協業親和性

---

## 決定事項 (ADR一覧)

> **ADR 分類規約・カテゴリ別インデックス**:
> 5大カテゴリ（ARC, DOM, DAT, APP, DEV）による体系化と整理指針は [adr/README.md](./adr/README.md) を参照。

- [**ADR-0001: プレフィックス付き UUID v7 (TypeID 方式) の識別子採用**](./adr/0001-surrogate-key-typeid-uuidv7.md): `mem_`, `grp_`, `col_` プレフィックス＋時系列ソート可能な UUID v7 による不変サロゲートキー戦略
- [**ADR-0002: バックエンド言語としての Go (Golang) の採用**](./adr/0002-backend-go-architecture.md): 構造体の自己文書化、AI コード生成精度、k8s 超軽量稼働 (10〜20MB)、Pure Go SQLite
- [**ADR-0003: デプロイ環境およびコンテナレジストリ選定**](./adr/0003-deployment-target-and-container-registry.md): 自宅 Proxmox k8s (Cloudflare Ingress) + GitHub Packages (`ghcr.io`) によるクラウド依存・コストゼロ運用
- [**ADR-0004: Go 構造体を正本とするスキーマ一元管理および自動生成パイプラインの採用**](./adr/0004-go-schema-as-single-source-of-truth.md): Go struct を Single Source of Truth とし、tygo / invopop 等で TS 型・OpenAPI・DDL を一括自動生成
- [**ADR-0005: データベース選定としての SQLite (WAL モード) の採用**](./adr/0005-database-selection-sqlite-wal.md): Cgo不要 Pure Go SQLite + WALモードによる並行読み書き、Litestream差分バックアップ
- [**ADR-0006: プレフィックス付きサロゲートキー (TypeID) と動的ドメインスキーマ構成の採用**](./adr/0006-domain-schema-and-typeid-structure.md): `grp_`, `col_`, `mem_`, `quiz_`, `usr_`, `ans_` による自然キー完全排除、青葉坂等への動的拡張
- [**ADR-0007: ライブ会場での完全動作を保証する Local-First / オフライン PWA アーキテクチャの採用**](./adr/0007-local-first-offline-pwa-architecture.md): Service Worker、CacheStorage、IndexedDB Outbox、純粋関数ローカル出題
- [**ADR-0008: 画像アセットの永久不変キャッシュ (RFC 8246 immutable) とゼロパージ運用の採用**](./adr/0008-immutable-image-caching-and-zero-purge.md): `mem_<uuidv7>.webp` 連動、永久キャッシュヘッダー、CDN パージ完全廃止
- [**ADR-0009: クイズ出題アルゴリズムにおける Strategy パターンの採用**](./adr/0009-quiz-generation-strategy-pattern.md): CIELAB色差類似色ひっかけ、忘却曲線復習、同期生出題のプラガブル分離
- [**ADR-0010: Google OIDC 認証と HttpOnly セッション Cookie の採用**](./adr/0010-google-oidc-authentication-and-session-security.md): 段階的オンボーディング、パスワードレス、HttpOnly Cookie による安全な端末間同期
- [**ADR-0011: プロジェクトディレクトリ構成および責務境界の策定**](./adr/0011-directory-structure-and-responsibility-boundaries.md): Standard Go Layout、単方向コード生成フロー、フロントエンド embed.FS 単一バイナリ Pod 運用
- [**ADR-0012: Kubernetes デプロイおよび ArgoCD GitOps アーキテクチャの採用**](./adr/0012-kubernetes-deployment-and-gitops-architecture.md): Cloudflare Ingress, cert-manager, ghcr.io, 単一Pod/PVC (Recreate), ArgoCD自動同期
- [**ADR-0013: AI 駆動開発を支える機械的支援ツールチェーンおよび超高速自律修復サイクルの採用**](./adr/0013-typescript-ai-agent-driven-development-toolchain.md): Knip（デッドコード駆除）、Biome/typos（Rust製超高速整形・タイポ検知）、ast-grep（構文パターン監査）、sqlc/Repomix（型安全生成・コンテキスト最適化）による機械的品質担保
- [**ADR-0014: エラー設計および最小 Problem Details 規約の採用**](./adr/0014-error-handling-and-minimal-problem-details.md): RFC 9457準拠、クライアント分岐に必要な最小6コード（INVALID_PARAMS, UNAUTHORIZED, FORBIDDEN, NOT_FOUND, INSUFFICIENT_MEMBERS, INTERNAL_ERROR）とinvalid_params集約
- [**ADR-0015: 最小環境変数および機密性分離アーキテクチャの採用**](./adr/0015-minimal-configuration-and-secrets-management.md): 機密値3種（SESSION_SECRET, GOOGLE_CLIENT_*）＋PVCデータパス（DATA_DIR）の計4変数のみに極小化、内部定数固定
- [**ADR-0016: ADR ガバナンスおよびフラット不変連番管理の採用**](./adr/0016-adr-governance-and-immutable-sequential-architecture.md): トピック別サブディレクトリのアンチパターン排除、単一フラットディレクトリ＋不変連番＋Frontmatter多面管理、追記型改廃ライフサイクル

---

## スキーマ規約・ドメイン定義方針 (Go Struct as Source of Truth)

- ドキュメント作成フェーズにおいて、曖昧な適当な JSON サンプルの散乱を防ぐため、**Go の構造体（`struct`）を機械可読な正本スキーマ** として定義・維持する。
- UUID v7 生成・検証等の低レイヤ処理は既存ライブラリ（`github.com/google/uuid` 等）を活用する前提とし、手組みの車輪の再発明や不要な単体テストは行わず、モデル規約の設計・ドキュメント化に集中する。
- 個別具体的な実データ（メンバー一覧など）はコンテキスト汚染を防ぐため、マスタ投入フェーズまで作成しない。

---

## アイデア・Nice to Have メモ

### 全画面サイリウムエミュレーター (Penlight Simulator)
- **概要**: メンバー詳細やクイズ正解画面から、ワンタップでスマートフォンの画面全体がそのメンバーの 2 色（左右半分ずつ）に発光・点滅するライブ会場用エミュレーター。
- **実用価値**: ライブ会場でペンライトを忘れた際、あるいは追加のサイリウムが必要になった際にスマホをそのまま掲げられる。
- **UI 工夫案**:
  - タップで左右のカラー配置を反転。
  - スライダーで画面輝度・点滅パルス速度を微調整。
  - 有機 EL (OLED) ディスプレイの黒背景省電力・高輝度発色を活用。
  - 実装優先度は Nice to Have（UI実装のフェーズで検討）。

---

## 現在の検討項目 (ドキュメント作成フェーズ)

- [x] 正本スキーマ定義の策定（`pkg/model/`: Group, Color, Member, Quiz, User, AnswerLog, DTO, Error）
- [x] 全体統括 Prefix Rule 仕様書の作成（`note/05_schema_and_domain_specification.md`）
- [x] クイズ出題アルゴリズムの Strategy パターン設計（`note/13_quiz_generation_strategy_pattern.md`）
- [x] Local-First オフライン PWA 設計（`note/11_local_first_offline_pwa_architecture.md`）
- [x] 永久不変キャッシュ規約（`note/12_immutable_image_caching_and_asset_pipeline.md`）
- [x] API 網羅仕様の策定（`note/10_api_specification_and_endpoints.md`）
- [x] OpenAPI 3.1.0 正本仕様書の配備（`api/openapi.yaml`）
- [x] SQLite テーブル DDL およびインデックス設計の配備（`migrations/000001_init.up.sql`）
- [x] エラー設計および最小 Problem Details 規約（`ADR-0014`, `note/20`, `pkg/model/error.go`）
- [x] 最小環境変数および機密性分離規約（`ADR-0015`, `note/21`, `pkg/config/config.go`, `.env.example`）
- [x] ADR ガバナンスおよびタグ統制一覧の確立（`ADR-0016`, `note/22`, `adr/README.md`）
- [x] 全体アーキテクチャ統合仕様書の作成（`note/19_system_architecture_overview.md`）
