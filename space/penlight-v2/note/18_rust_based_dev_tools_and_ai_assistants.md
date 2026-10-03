# Rust 製超高速開発ツール群および AI 支援エコシステム調査 (18_rust_based_dev_tools_and_ai_assistants.md)

本ドキュメントは、2025〜2026年にかけて開発エコシステムを席巻している **Rust 製の超高速静的解析・コード変換ツール**、および **AI コーディングエージェントの作業品質を機械的に支援する最新ツール群** を入念に調査・整理し、本プロジェクト（`penlight-v2`）で「試して価値を検証すべきツール群」をまとめた技術仕様書です。

技術を禁止するのではなく、**「人間や AI の主観・目視に頼らず、ミリ秒単位で機械的に正誤判定・自動修正・解析を行えるツールを多角的に導入する」** ことを目的とします。

---

## 1. Rust 製最新開発ツール一覧マトリクス

JavaScript/Node.js 製のツールから Rust 製ツールへの移行により、実行速度が 20〜100 倍に高速化され、AI エージェントが待たずに自己修正ループを回せるようになっています。

| ツール名 | 実装言語 | カテゴリ / 役割 | 解決する課題・AI 開発での効果 | 公式リンク |
|---|---|---|---|---|
| **Biome** | **Rust** | フォーマッター & リンター統合 | ESLint / Prettier を 1 つのバイナリで代替。15ms の超高速実行で AI の構文乱れを即座に自動修正 | [biomejs.dev](https://biomejs.dev/) |
| **Oxlint (Oxc)** | **Rust** | 超高速 ESLint 特化代替 | ESLint 比 50〜100 倍高速。Next.js / React / TypeScript ルールをネイティブ実装し、大規模コードを一瞬でスキャン | [oxc.rs](https://oxc.rs/) |
| **ast-grep (`sg`)** | **Rust** | 構造的 AST 検索 & リライト | 正規表現を超えた「構文木パターンマッチング」。AI が生成したアンチパターンの機械的検出・自動置換を実行 | [ast-grep.github.io](https://ast-grep.github.io/) |
| **typos** | **Rust** | ソースコード特化スペルチェッカー | 変数名、コメント、ドキュメントの誤字脱字をミリ秒で検出。AI が混入させた珍妙な typo を機械的に排除 | [github.com/crate-ci/typos](https://github.com/crate-ci/typos) |
| **mise** | **Rust** | 高速環境・ツールバージョン管理 | `asdf` / `direnv` の Rust 製代替。Go, Node.js, pnpm, 各種 CLI ツールのバージョンと環境変数を 1 箇所で固定 | [mise.jdx.dev](https://mise.jdx.dev/) |
| **git-cliff** | **Rust** | 高度な CHANGELOG 自動生成 | Conventional Commits のコミットログから、セマンティックなリリースノートを Rust で爆速自動生成 | [git-cliff.org](https://git-cliff.org/) |

---

## 2. AI コーディングエージェント支援ツール

AI にコードベースの文脈を正しく伝え、AI が散らかした負債を自動で掃除するための専用ツールです。

| ツール名 | カテゴリ / 役割 | AI 開発での具体的効果 | 公式リンク |
|---|---|---|---|
| **Repomix** (旧 Repopack) | **コードベース AI パッキング** | リポジトリ構造とコードを、LLM が最も理解しやすい XML/Markdown 形式に 1 ファイル圧縮・集約。コンテキスト節約と理解精度向上 | [repomix.com](https://repomix.com/) |
| **Knip** | **コード衛生・デッドコード駆除** | AI が残した未使用の export、不要な依存関係、孤立ファイルを依存グラフから機械的検出・一括削除 (`knip --fix`)。MCP 連携対応 | [knip.dev](https://knip.dev/) |
| **sqlc** | **SQL からの型安全 Go コード生成** | AI に面倒な DB マッピングコードを書かせず、SQL クエリから 100% 型安全な Go コードを機械生成 | [sqlc.dev](https://sqlc.dev/) |
| **Spectral** | **OpenAPI 仕様書の機械的リント** | 自動生成された OpenAPI 3.1 仕様書が命名規則や REST 規約を満たしているかを機械的にルール検証 | [stoplight.io/open-source/spectral](https://stoplight.io/open-source/spectral) |

---

## 3. 各ツールの実践的活用法と導入コマンド

### 3.1 `typos`: AI が生成したコード・ドキュメントのスペルミス自動検知
AI は稀にプロパティ名やコメントで微妙なスペルミス（例: `seleted_id`, `penlihgt` 等）を起こします。これをコンパイル前にミリ秒で検出します。

```bash
# インストール (Homebrew または cargo)
brew install typos-cli

# 検査実行 (リポジトリ全体を一瞬でチェック)
typos

# 自動修正
typos -w
```
- **特徴**: コードの識別子（キャメルケース、スネークケース）を理解し、変数名を壊さずにスペルチェックを行う。

---

### 3.2 `ast-grep` (`sg`): 構文パターンによる機械的ガードレール
「非推奨の関数が使われていないか」「安全でない型キャストが行われていないか」を AST レベルで検出・置換します。

#### ルール例 (`sgconfig.yml`)
```yaml
id: no-raw-fetch-in-components
language: typescript
rule:
  pattern: fetch($$$ARGS)
  inside:
    kind: function_declaration
    stopBy: end
message: "React コンポーネント内で直接 fetch を呼ぶことは禁止されています。API クライアントまたは SWR/React Query を使用してください。"
fix: apiClient.get($$$ARGS)
```
- **実行**: `ast-grep scan`
- AI が禁止パターンを踏んだ際、理由と自動修正案（`fix`）を提示して機械的に自己修正させることが可能です。

---

### 3.3 `Oxlint` (Oxc): CI およびローカルでの超爆速リント
Biome がオールインワン（整形＋リント）であるのに対し、Oxlint は ESLint ルールへの互換性に特化した最速のリンターです。

```bash
# 実行 (設定ファイルなしでも主要ルールが即座に動作)
npx oxlint@latest --import-plugin
```
- 200 以上の主要 ESLint / React / TypeScript ルールをミリ秒単位で検査可能。

---

### 3.4 `Repomix`: AI エージェントへのコンテキスト投入
外部の AI（Claude, Gemini, Antigravity 等）に「リポジトリ全体の設計とコードを把握してほしい」際、不要なファイル（`node_modules`, `dist`, 画像バイナリ等）を除外し、綺麗に構造化された 1 ファイルを出力します。

```bash
# 設定ファイル (repomix.config.json) に基づいてパッキング
npx repomix

# 出力成果物: repomix-output.xml (これを AI に渡すだけで全体把握が可能)
```

---

## 4. 本プロジェクトでの導入フェーズ・推奨スタック

一気に全てを入れるのではなく、以下の段階的なロードマップで「手触り」を試しながら組み込みます。

```
[Phase 1: 即時導入 (基盤)]
  ├── Biome (フォーマット & リント統合)
  ├── typos (スペルチェック)
  └── Knip (未使用コード駆除)

[Phase 2: コード生成 & 衛生]
  ├── sqlc (SQL からの Go コード生成)
  └── Repomix (AI コンテキスト最適化)

[Phase 3: 高度な品質保証 (必要に応じて検証)]
  ├── ast-grep (カスタム構文ルール)
  └── Oxlint (大規模ファイル向け並列リント)
```

---

## 5. 参考文献・公式仕様

- [Biome Official Website](https://biomejs.dev/)
- [Oxc / Oxlint - The Oxidation Compiler](https://oxc.rs/)
- [ast-grep Documentation](https://ast-grep.github.io/)
- [typos - Source code spell checker (GitHub)](https://github.com/crate-ci/typos)
- [Repomix - Pack repository into a single AI-friendly file](https://repomix.com/)
- [sqlc - Compile SQL to type-safe Go](https://sqlc.dev/)
- [mise-en-place - Development environment manager](https://mise.jdx.dev/)
- [git-cliff - Highly customizable Changelog Generator](https://git-cliff.org/)
