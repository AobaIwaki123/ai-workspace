# ADR 分割方針およびアーキテクチャ決定ガバナンスのベストプラクティス (22_adr_partitioning_and_governance_best_practices.md)

本ドキュメントは、ソフトウェア開発およびアーキテクチャ意思決定記録（Architecture Decision Records, ADR）の運用において、**「ADR が増加した際にどのように分割・管理すべきか」** に関する業界のベストプラクティス、アンチパターン、および AI エージェント協業時代における最適なガバナンスモデルを整理した技術調査ノートです。

---

## 1. 課題提起: ADR 肥大化に伴う分割の誘惑と罠

システム設計が進み、ADR の件数が 10〜20 件を超えてくると、多くの開発チームが「見通しを良くしたい」という動機から、以下のような **トピック別サブディレクトリ分割** を検討しがちです。

```
adr/ (直感的なサブディレクトリ分割案)
├── arc/  # アーキテクチャ・インフラ
├── dom/  # ドメインモデル
├── dat/  # データベース・ストレージ
├── app/  # アプリケーション機能
└── sec/  # セキュリティ
```

しかし、業界の大規模システム運用および長年の実践において、**この直感的なトピック別物理分割は典型的なアンチパターン** とされています。

---

## 2. アンチパターンとしての「トピック別サブディレクトリ分割」

なぜトピック別のサブディレクトリ分割が破綻するのか、以下の 3 つの構造的欠陥が存在するためです。

### 2.1 関心事の重複と分類の認知摩擦 (Orthogonality Violation)
現実のアーキテクチャ判断は、単一のトピックに綺麗に収まることは極めて稀です。
- **例1**: 「SQLite WAL モードの採用」は、データベース（`dat/`）の決定であると同時に、単一 Pod デプロイ・Recreate 戦略というインフラ基盤（`arc/`）の決定でもある。
- **例2**: 「Local-First オフライン PWA」は、オフラインクイズ体験（`app/`）であると同時に、Service Worker / IndexedDB を用いたシステム構造（`arc/`）の決定でもある。

ファイルシステム上、1 つの Markdown ファイルは物理的に 1 つのディレクトリにしか配置できません。結果として、**「この ADR はどこに配置すべきか」という不毛な議論（バイク小屋効果）** が PR レビューごとに発生し、分類の属人化が進みます。

### 2.2 外部リンクと永続的コンテキストの破損 (Broken References)
将来、カテゴリの再編や新カテゴリ（例: `perf/` パフォーマンス、`ops/` 運用）の新設に伴って ADR ファイルを移動した瞬間、以下の参照がすべて破壊されます。
1. 過去の Git コミットメッセージ内の言及（`Refs: adr/arc/0002-...`）
2. マージ済み Pull Request や Issue のディスカッション
3. ソースコード内に埋め込まれた意思決定参照コメント（`// See: ADR-0005`）
4. 他のドキュメント（`note/*.md`, `README.md`）からの相対リンク

### 2.3 ナンバリングの多重化・衝突 (Namespace Collisions)
ディレクトリごとに番号を振ると（`arc/0001`, `dom/0001`）、会話やレビューで「ADR-0001」と呼んだ際に一意性が失われます。
逆にグローバル連番（`0001`, `0002`...）を維持したまま各フォルダに分散させると、`arc/` の中には `0002`, `0003`, `0011`, `0012` が虫食い状に並び、ディレクトリとしての連続性が失われます。

---

## 3. 世界標準のベストプラクティス (The Gold Standard)

Michael Nygard の提唱した原典、MADR (Markdown Any Decision Records)、Thoughtworks、および大規模 OSS プロジェクト（Kubernetes, Rust, Spotify 等）が採用している標準的ベストプラクティスは以下の 4 原則に集約されます。

### 原則 1: 単一フラットディレクトリ + グローバル不変連番 (Global Immutable Surrogate Key)
- ディレクトリ構造は細分化せず、**`adr/` 直下の単一ディレクトリに全ファイルをフラットに配置** します。
- ファイル名は `0001-xxx.md`, `0002-xxx.md` という **システム全体で一意・不変・時系列ソート可能なグローバル連番** を付与します。
- **効果**: ファイルシステムを「不変 ID の物理ストレージ」に徹させることで、ファイル移動によるリンク破損リスクを恒久的にゼロにします。

### 原則 2: メタデータ (Frontmatter) による多面分類 (Facet Classification)
物理ディレクトリで分類する代わりに、各 ADR の先頭に **YAML Frontmatter** を付与し、論理的な分類を委譲します。

```yaml
---
id: ADR-0005
title: データベース選定としての SQLite (WAL モード) の採用
status: Accepted
scope: System
primary_category: DAT
categories: [DAT, ARC]
tags: [sqlite, storage, wal, litestream, disaster-recovery]
superseded_by: null
amends: null
deciders: [user, ai]
date: 2026-10-02
---
```

- **効果**: 1 つの ADR が複数の領域（`categories: [DAT, ARC]`）に関わる場合でも、自然に多面管理（Facet）が可能になります。
- **インデックス自動生成**: `adr/README.md` やカテゴリ別一覧は、スクリプト（または GitHub Actions）が Frontmatter をパースして機械的に動的生成（Single Source of Truth, Multiple Views）します。

### 原則 3: 追記型の改廃ライフサイクル (Append-only & Supersede)
一度採択（`Accepted`）された ADR は、過去の経緯を改ざんしないため **本文の決定内容を直接書き換えることを禁止** します。
方針変更や技術刷新が発生した場合は、新しい ADR を起票し、双方向リンクを張って上書きします。

```
[Draft] -> [Proposed] -> [Accepted] -> [Superseded by ADR-xxxx]
                       \             \
                        -> [Rejected] -> [Deprecated]
```

- **旧 ADR**: ステータスを `Superseded` に変更し、新 ADR へのリンクを明記。
- **新 ADR**: 本文に「ADR-yyyy を置き換える決定」であることを明記し、なぜ過去の前提が崩れたかの差分理由を記録。

### 原則 4: 真の物理分割は「システムスコープ（境界づけられたコンテキスト）」でのみ行う
もし将来、物理的にディレクトリを分けるべき必然性が発生した場合、分けるべき軸は「トピック（インフラ、DB等）」ではなく、**「境界づけられたコンテキスト（Bounded Context / サブシステム）」** です。

```
space/penlight-v2/
├── adr/                       # 【全体】システム横断アーキテクチャ (Go, SQLite, k8s, OIDC)
├── frontend/
│   └── docs/adr/              # 【局所】フロントエンド固有 (React 状態管理, UI ライブラリ規約)
└── backend/
    └── docs/adr/              # 【局所】バックエンド固有 (ORM 選定, ルーティングミドルウェア構造)
```

- **効果**: 単一のサブシステム内に閉じた詳細な決定が、システム全体の ADR 一覧を埋め尽くす（ノイズ化する）のを防ぎ、コンポーネントの自律的な進化を支援します。

---

## 4. AI エージェント協業時代における ADR ガバナンス

AI コーディングアシスタント（Agentic AI）と協業する開発環境において、この「フラット連番 + Frontmatter」モデルは以下の決定的な利点をもたらします。

1. **探索オーバーヘッドの最小化**:
   - ディレクトリが多層化されていると、AI はファイル一覧を取得するために複数回の `ls` や `find` ツールコールを実行し、コンテキストトークンを浪費します。フラット構成であれば `adr/` を 1 回スキャンするだけで全体を網羅できます。
2. **トークン密度の最適化**:
   - AI は Frontmatter のメタデータ（ID、タイトル、カテゴリ、タグ）だけを読み取ることで、本文を全読することなく、今解いているタスクに関連する ADR を瞬時に特定（Pruning）できます。
3. **機械的整合性検証の自動化**:
   - Biome や ast-grep、あるいは簡単なスクリプト（`validate-adr.sh`）により、Frontmatter の必須フィールド欠落、ステータス遷移の不整合、存在しない ID へのリンク切れをミリ秒単位で静的検査できます。

---

## 5. 参考文献・権威ある情報源

- [Michael Nygard - Documenting Architecture Decisions (2011)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Thoughtworks Technology Radar - Lightweight Architecture Decision Records](https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records)
- [MADR - Markdown Architectural Decision Records (GitHub Standard)](https://adr.github.io/madr/)
- [Spotify Engineering - When Should We Write an ADR?](https://engineering.atspotify.com/2020/04/when-should-we-write-an-adr/)
- [Joel Parker Henderson - Architecture Decision Record (ADR) Repository Pattern](https://github.com/joelparkerhenderson/architecture-decision-record)
