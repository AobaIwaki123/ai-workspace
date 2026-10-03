# Architecture Decision Records (ADR) 分類規約・インデックス

本ドキュメントは、Penlight Quiz v2 におけるアーキテクチャ意思決定記録（ADR）の **分類カテゴリ体系（タキソノミー）**、**命名・ナンバリング規約**、および **全 ADR のカテゴリ別マッピング目次** を定めた規約書です。

> **運用上の注意**:
> 現在は開発着手前・設計フェーズのため **物理的なディレクトリ移動は行わず、`adr/` 直下のフラットな連番ファイルとして保持** します。開発開始時または運用拡大時に、本規約に基づいて整理を実施します。

---

## 1. ADR 5大分類カテゴリ (Taxonomy)

| カテゴリ | 略称コード | 対象領域・スコープ | 主な決定内容 |
|---|---|---|---|
| **System Architecture & Infra** | `ARC` | システム構造、言語選定、k8s デプロイ、GitOps、ディレクトリ構成 | 実行基盤、ネットワーク、ビルド形態、全体境界 |
| **Domain & Data Modeling** | `DOM` | ドメインモデル、サロゲートキー、スキーマ正本、動的マスタ | 識別子規約 (TypeID)、動的グループ拡張、同姓同名対策 |
| **Data & Storage** | `DAT` | データベース、ストレージ、キャッシュ、アセット配信 | SQLite WAL、Litestream、不変画像配信 (`immutable`) |
| **Application & Feature** | `APP` | アプリケーション機能、出題アルゴリズム、認証、PWA | Local-First、CIELAB 色差出題、Google OIDC |
| **Developer Experience & Tooling** | `DEV` | 開発体験、AI コーディング支援、静的解析、コード衛生 | Knip、Biome、typos、ast-grep、自律修復 CI |

---

## 2. 全 ADR カテゴリ別インデックス (0001 〜 0016)

### 2.1 ARC: System Architecture & Infrastructure (システム基盤・デプロイ)

| 番号 | タイトル | 核心の決定内容 |
|---|---|---|
| [**0002**](./0002-backend-go-architecture.md) | バックエンド言語としての Go (Golang) の採用 | 15MB 超軽量稼働、Cgo-free、AI コード生成精度最大化 |
| [**0003**](./0003-deployment-target-and-container-registry.md) | デプロイ環境およびコンテナレジストリ選定 | 自宅 k8s + Cloudflare Ingress + `ghcr.io` (クラウド費用ゼロ) |
| [**0011**](./0011-directory-structure-and-responsibility-boundaries.md) | プロジェクトディレクトリ構成および責務境界の策定 | Standard Go Layout、単方向コード生成フロー、フロント内包単一 Pod |
| [**0012**](./0012-kubernetes-deployment-and-gitops-architecture.md) | Kubernetes デプロイおよび ArgoCD GitOps アーキテクチャの採用 | Cloudflare Tunnel、cert-manager、Recreate 戦略 (1 Pod/PVC) |
| [**0015**](./0015-minimal-configuration-and-secrets-management.md) | 最小環境変数および機密性分離アーキテクチャの採用 | 機密値3種＋PVCデータパス1種の計4変数に極小化、内部定数固定 |

### 2.2 DOM: Domain & Data Modeling (ドメインモデル・スキーマ)

| 番号 | タイトル | 核心の決定内容 |
|---|---|---|
| [**0001**](./0001-surrogate-key-typeid-uuidv7.md) | プレフィックス付き UUID v7 (TypeID) によるサロゲートキーの採用 | 自然キー完全排除、`mem_`, `grp_` 等によるエンティティ即時判別 |
| [**0004**](./0004-go-schema-as-single-source-of-truth.md) | Go 構造体を正本とするスキーマ一元管理および自動生成パイプラインの採用 | Go struct を Single Source of Truth とし、TS型・OpenAPI・DDL 自動同期 |
| [**0006**](./0006-domain-schema-and-typeid-structure.md) | プレフィックス付きサロゲートキーと動的ドメインスキーマ構成の採用 | 青葉坂46 等の動的追加 (Enum 排除)、同姓同名・改名耐性、左右独立カラー |

### 2.3 DAT: Data & Storage (データベース・ストレージ・キャッシュ)

| 番号 | タイトル | 核心の決定内容 |
|---|---|---|
| [**0005**](./0005-database-selection-sqlite-wal.md) | データベースとしての SQLite (WAL モード) の採用 | Pure Go 組み込み SQLite、並行読み書き、Litestream 秒単位レプリケーション |
| [**0008**](./0008-immutable-image-caching-and-zero-purge.md) | 画像アセットの永久不変キャッシュ (RFC 8246 immutable) とゼロパージ運用の採用 | `mem_<uuidv7>.webp` 連動、304 再検証不要の 0ms 読み込み、CDN パージ撤廃 |

### 2.4 APP: Application & Feature (アプリケーション・ロジック・認証)

| 番号 | タイトル | 核心の決定内容 |
|---|---|---|
| [**0007**](./0007-local-first-offline-pwa-architecture.md) | ライブ会場での完全動作を保証する Local-First / オフライン PWA アーキテクチャの採用 | 電波飽和エリアでの 0ms 出題、IndexedDB、Outbox バックグラウンド一括同期 |
| [**0009**](./0009-quiz-generation-strategy-pattern.md) | クイズ出題アルゴリズムにおける Strategy パターンの採用 | CIELAB 色差 ($\Delta E$) 類似色ひっかけ、忘却曲線苦手克服のプラガブル分離 |
| [**0010**](./0010-google-oidc-authentication-and-session-security.md) | Google OIDC 認証と HttpOnly セッション Cookie の採用 | 段階的オンボーディング、パスワードレス、XSS を防ぐ安全なセッション管理 |
| [**0014**](./0014-error-handling-and-minimal-problem-details.md) | エラー設計および最小 Problem Details 規約の採用 | RFC 9457準拠、クライアント分岐に必要な最小6コード＋invalid_params集約 |

### 2.5 DEV: Developer Experience & Tooling (開発体験・AI 支援)

| 番号 | タイトル | 核心の決定内容 |
|---|---|---|
| [**0013**](./0013-typescript-ai-agent-driven-development-toolchain.md) | AI 駆動開発を支える機械的支援ツールチェーンおよび超高速自律修復サイクルの採用 | Knip（デッドコード駆除）、Biome/typos（Rust製超高速検証）、ast-grep（構文監査） |
| [**0016**](./0016-adr-governance-and-immutable-sequential-architecture.md) | ADR ガバナンスおよびフラット不変連番管理の採用 | 単一フラットディレクトリ＋グローバル連番＋Frontmatter多面管理、追記型進化 |

---

## 3. ADR 分割方針と拡張性設計 (Extensible Governance)

プロジェクトの長期運用、規模拡大、および AI エージェントによる自律探索に対応するため、本リポジトリでは以下の拡張性原則に基づいた ADR 分割・運用方針を採用します。

### 3.1 グローバル不変連番 (Global Immutable ID) 原則
- カテゴリ別のローカル採番（例: `arc/0001`, `dom/0001`）は**採用しません**。
- `ADR-0001` から `ADR-9999` までの**システム全体で一意なグローバル連番**を絶対識別子（サロゲートキー）とします。
- **理由**:
  - コミットログ、PR、Issue、ソースコード内の注釈コメント（`// Ref: ADR-0005`）において、「ADR-0005」と記述するだけで衝突なく一意に特定できるため。
  - 将来ファイル配置やカテゴリ分類の組み換えが発生しても、ID の恒久性が保たれ、外部参照が一切破損しないため。

### 3.2 2層スコープ分離 (System-wide vs Component-level)
プロジェクトの成長に伴い、システム全体の意思決定と各コンポーネント局所の意思決定が混在して ADR が肥大化するのを防ぐため、以下の2層スコープで分割を許容します。

| スコープ | 格納ディレクトリ | 対象領域 | 例 |
|---|---|---|---|
| **System-wide (システム横断)** | `adr/` (現行) | リポジトリ全体、言語選定、DB選定、認証プロトコル、インフラ構成、共通開発規約 | Go採用 (0002)、SQLite WAL (0005)、OIDC (0010) |
| **Component-level (局所実装)** | `frontend/adr/`, `backend/adr/` (必要時) | 単一コンポーネント内に閉じたライブラリ選定、状態管理パターン、内部層設計 | React状態管理ライブラリ、特定のGo HTTPミドルウェア構造 |

※ 現在のフェーズではすべて `System-wide`（`adr/` 直下）に集約し、コンポーネント固有の決定が10件以上蓄積した段階で局所ディレクトリの増設を検討します。

### 3.3 単一責任の決定粒度 (Single Responsibility Decision)
- 1つの ADR は**「単一の技術的問い・トレードオフ」**のみを扱います。
- 複数のアーキテクチャ判断（例: 言語選定とDB選定）を1つの ADR に混載しません。
- 決定間に依存関係がある場合は、本文の関連 ADR リンクおよび Frontmatter の `relations` で結合します（疎結合な決定の積み上げ）。

### 3.4 イミュータブルな改廃ライフサイクル (Append-only Evolution)
一度 `Accepted`（採択）された ADR は、歴史的記録（改ざん防止）として**後から本文の決定内容を直接書き換えて変更することを禁止**します。方針転換や技術刷新が発生した場合は、以下のライフサイクルに従って新しい ADR を起票します。

```
[Draft] -> [Proposed] -> [Accepted] -> [Superseded by ADR-xxxx]
                       \             \
                        -> [Rejected] -> [Deprecated]
```

- **ステータス定義**:
  - `Draft`: 起草中（ユーザーとの壁打ち段階）
  - `Proposed`: 提案・レビュー中
  - `Accepted`: 合意・確定
  - `Rejected`: 検討の結果不採用（棄却理由と得られた教訓を記録）
  - `Deprecated`: 機能廃止や外部要因により決定の有効性が喪失
  - `Superseded`: 後続の新しい ADR によって上書き・代替された状態
- **上書きの作法**:
  - 旧 ADR のステータスを `Superseded` に更新し、冒頭に `> **代替**: 本決定は [ADR-xxxx](./xxxx-...) によって置き換えられました。` と明記。
  - 新 ADR 側には `> **置換元**: 本決定は [ADR-yyyy](./yyyy-...) を再評価し、置き換えるものです。` と背景を記載。

### 3.5 メタデータ標準化 (Frontmatter 規約)
物理ディレクトリに依存しない多面分類（Facet）や、AI エージェント・自動化スクリプトによるインデックス生成を可能にするため、各 ADR の先頭に以下の Frontmatter を定義することを推奨標準とします。

```yaml
---
id: ADR-0005
title: データベース選定としての SQLite (WAL モード) の採用
status: Accepted
scope: System
primary_category: DAT
categories: [DAT, ARC]
tags: [sqlite, wal, litestream]
superseded_by: null
amends: null
deciders: [user, ai]
date: 2026-10-02
---
```

### 3.6 公式タグ統制一覧 (Controlled Tag Vocabulary)

タグの無秩序な増殖や表記揺れ（例: `auth` と `authentication`, `sqlite` と `sqlite3`）を防ぎ、AI やスクリプトによる分類の精度を担保するため、**タグは大元（本節）で一元管理（Allowlist 運用）** します。

- **ルール**:
  1. 各 ADR に付与するタグは、**以下の公式許可タグからのみ選択可能**（アドホックな勝手なタグ付けは禁止）。
  2. 1 つの ADR に付与できるタグは **最大 3〜4 個** まで（過剰なタグ付けの禁止）。
  3. 新規タグが必要になった場合は、必ず本表への追加提案・合意を経てから使用する。

| カテゴリ | 公式許可タグ (Allowlist) | 対象スコープ |
|---|---|---|
| **ARC** (基盤・デプロイ) | `go`, `k8s`, `cloudflare`, `gitops`, `monorepo`, `directory-structure`, `configuration` | システム構造、実行言語、インフラ、環境設定 |
| **DOM** (ドメイン・スキーマ) | `typeid`, `uuidv7`, `single-source-of-truth`, `surrogate-key`, `extensible-group` | 識別子設計、正本構造体、拡張グループ設計 |
| **DAT** (データ・ストレージ) | `sqlite`, `wal`, `litestream`, `immutable-cache`, `s3-backup` | 永続化、ファイルI/O、キャッシュ制御 |
| **APP** (アプリ・機能) | `local-first`, `pwa`, `quiz-strategy`, `oidc`, `problem-details`, `cielab` | クイズアルゴリズム、認証、オフライン、エラー |
| **DEV** (開発体験・規約) | `toolchain`, `biome`, `knip`, `adr-governance`, `yagni` | コード衛生、静的解析、ADR規約、設計原則 |

---

## 4. 将来の物理ディレクトリ整理方針

開発着手時または ADR 総数が 20 件を超えた場合、以下のいずれかの物理構造への段階的移行を行います。

1. **方式 A: グローバル連番 + カテゴリプレフィックス (推奨・互換性高)**:
   - `adr/0001-dom-surrogate-key-typeid-uuidv7.md`
   - `adr/0002-arc-backend-go-architecture.md`
   - `adr/0005-dat-database-selection-sqlite-wal.md`
   - *メリット*: ディレクトリが1箇所にまとまり、一覧性と時系列順ソートを保ちつつ、ファイル名だけでカテゴリが判別可能。リンク切れリスクが最小。
2. **方式 B: カテゴリ別サブディレクトリ (スコープ明確化)**:
   - `adr/arc/0002-backend-go-architecture.md`
   - `adr/dom/0001-surrogate-key-typeid-uuidv7.md`
   - `adr/dat/0005-database-selection-sqlite-wal.md`
   - *注意*: 番号はグローバル連番を維持し、虫食い採番を許容する（`arc/` 内に 0002, 0003, 0011, 0012 が並ぶ）。

※ 現時点（設計フェーズ）では、他セッションとの作業ツリー衝突および相対リンク破損を防止するため、**`adr/000X-...` のフラットな連番ファイルを維持** します。

