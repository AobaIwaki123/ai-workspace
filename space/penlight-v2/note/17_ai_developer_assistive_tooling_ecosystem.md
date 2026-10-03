# AI 補助ツールおよび開発支援エコシステム総覧 (17_ai_developer_assistive_tooling_ecosystem.md)

本ドキュメントは、AI コーディングエージェント（Claude Code / Antigravity / Cursor 等）および人間が協業する上で、**「AI の曖昧な主観判断や人間の目視確認に頼らず、機械的に解析・生成・修正・衛生管理を支援する便利ツール群」** を体系的に整理した技術リファレンスです。

---

## 1. AI 補助ツールの 7 大カテゴリと全体像

```
                      ┌─── [1. コンテキスト最適化] ───► Repomix, code2prompt
                      │
                      ├─── [2. コード衛生・デッドコード駆除] ─► Knip, depcheck
                      │
                      ├─── [3. AST 構造検索・リライト] ──► ast-grep, ts-morph
                      │
[AI 協業パイプライン] ──┼─── [4. 型安全・コード自動生成] ────► sqlc, tygo, invopop
                      │
                      ├─── [5. 超高速静的検証 (Rust製)] ─► Biome, Oxlint, typos
                      │
                      ├─── [6. 型安全プロンプト・LLM統合] ─► BAML, Vercel AI SDK
                      │
                      └─── [7. テスト品質・ミューテーション] ─► Stryker, mutmut
```

---

## 2. カテゴリ別 注目ツール詳細マトリクス

### 2.1 コンテキスト最適化 & リポジトリ要約 (Context Packing)
AI エージェントにコードベースの全体像をインプットする際、トークン数を浪費せず、最も理解しやすい形式に構造化して渡すツールです。

| ツール名 | 種別 | 特徴と AI 開発での効果 | 公式リンク |
|---|---|---|---|
| **[Repomix](https://repomix.com/)** (旧 Repopack) | CLI / Node.js | リポジトリ構造とファイルを、LLM が最も解析しやすい XML / Markdown 形式で 1 ファイルに圧縮集約。`.repomixignore` による不要ファイル除外、トークン数推定機能を備える | [repomix.com](https://repomix.com/) |
| **[code2prompt](https://github.com/mufeedvh/code2prompt)** | CLI / Rust | Rust 製の超高速コードベースプロンプト化ツール。Jinja2 テンプレートを用いて、AI へのプロンプト形式をカスタマイズ可能 | [github.com/mufeedvh/code2prompt](https://github.com/mufeedvh/code2prompt) |

### 2.2 コード衛生・デッドコード自動駆除 (Codebase Hygiene)
AI が機能追加を繰り返す中で放置しがちな「使われなくなった関数・export・孤立ファイル」を機械的に検出・削除します。

| ツール名 | 種別 | 特徴と AI 開発での効果 | 公式リンク |
|---|---|---|---|
| **[Knip](https://knip.dev/)** | CLI / MCP | プロジェクト全体の依存グラフを解析し、未使用のファイル、export、型、`package.json` の不要な依存を特定。`knip --fix` で自動削除。**Knip MCP サーバー** を通じて AI 自身に掃除を実行させることが可能 | [knip.dev](https://knip.dev/) |
| **[depcheck](https://github.com/depcheck/depcheck)** | CLI / Node.js | `package.json` に記載されているがコード内で一度もインポートされていない不要な npm パッケージを検出 | [github.com/depcheck/depcheck](https://github.com/depcheck/depcheck) |

### 2.3 AST 構造検索 & 決定論的コード書き換え (AST & Structural Manipulation)
AI による「曖昧な正規表現テキスト置換」による構文破壊を防ぎ、抽象構文木（AST）レベルで型安全に一括修正します。

| ツール名 | 種別 | 特徴と AI 開発での効果 | 公式リンク |
|---|---|---|---|
| **[ast-grep (`sg`)](https://ast-grep.github.io/)** | CLI / Rust | 言語横断（Go, TS, JS 等）で使える AST パターンマッチングツール。コードの構造を理解した上で検索・置換が可能。AI の生成した非推奨コードの検知・自動修正に最適 | [ast-grep.github.io](https://ast-grep.github.io/) |
| **[ts-morph](https://ts-morph.com/)** | ライブラリ / TS | TypeScript Compiler API の高機能ラッパー。プログラムから TypeScript のクラス、型エイリアス、インターフェースを直接書き換え可能 | [ts-morph.com](https://ts-morph.com/) |

### 2.4 型安全・コード自動生成 (Type & Code Generation)
AI に手書きのボイラープレート（DB マッピングや型変換）を書かせず、宣言的なスキーマや SQL から 100% 正しいコードを機械生成します。

| ツール名 | 種別 | 特徴と AI 開発での効果 | 公式リンク |
|---|---|---|---|
| **[sqlc](https://sqlc.dev/)** | CLI / Go | プレーンな SQL クエリから、完全に型安全な Go のリポジトリコードとモデルを自動生成。AI に `rows.Scan` 等の手動パースを書かせない | [sqlc.dev](https://sqlc.dev/) |
| **[tygo](https://github.com/gzuidhof/tygo)** | CLI / Go | Go の AST を解析し、Go 構造体から忠実な TypeScript 型定義を出力 | [github.com/gzuidhof/tygo](https://github.com/gzuidhof/tygo) |
| **[invopop/jsonschema](https://github.com/invopop/jsonschema)** | ライブラリ / Go | Go 構造体から JSON Schema (Draft 2020-12) を 1 発生成 | [github.com/invopop/jsonschema](https://github.com/invopop/jsonschema) |

### 2.5 超高速静的検証 (Sub-second Verification, Rust 製)
AI の思考テンポを崩さない、ミリ秒（10〜30ms）で判定が返る超高速な検証器です。

| ツール名 | 種別 | 特徴と AI 開発での効果 | 公式リンク |
|---|---|---|---|
| **[Biome](https://biomejs.dev/)** | CLI / Rust | フォーマッター & リンター統合。ESLint/Prettier の 20 倍高速（15ms）。AI 生成直後のフォーマット崩れをミリ秒で自己修復 | [biomejs.dev](https://biomejs.dev/) |
| **[Oxlint](https://oxc.rs/)** | CLI / Rust | Oxc プロジェクトの超高速リンター。ESLint プラグイン（React, TS）互換ルールをネイティブ実装 | [oxc.rs](https://oxc.rs/) |
| **[typos](https://github.com/crate-ci/typos)** | CLI / Rust | ソースコード特化スペルチェッカー。キャメルケースやスネークケースを保持したまま、変数名やコメントのタイポをミリ秒で検出 | [github.com/crate-ci/typos](https://github.com/crate-ci/typos) |

### 2.6 型安全プロンプト・LLM 統合 (Prompt & LLM Engineering)
LLM の出力を型安全に受け取り、パースエラー（ハルシネーション）を根本から遮断します。

| ツール名 | 種別 | 特徴と AI 開発での効果 | 公式リンク |
|---|---|---|---|
| **[BAML](https://www.boundaryml.com/)** | 言語・CLI | Boundary ML 製の AI プログラミング言語。プロンプトを「型付き関数」として定義し、TypeScript クライアントを自動生成 | [boundaryml.com](https://www.boundaryml.com/) |
| **[Vercel AI SDK](https://sdk.vercel.ai/)** | ライブラリ / TS | React / Next.js に最適化された AI 統合コア。`generateObject` により Zod / Valibot スキーマに基づく構造化出力を強制 | [sdk.vercel.ai](https://sdk.vercel.ai/) |

### 2.7 テスト品質・ミューテーション検証 (Test Quality Verification)
AI が書いた単体テストが「本当にバグを検知できる有効なテストか」を機械的に判定します。

| ツール名 | 種別 | 特徴と AI 開発での効果 | 公式リンク |
|---|---|---|---|
| **[Stryker Mutator](https://stryker-mutator.io/)** | CLI / TS・JS | JavaScript/TypeScript 向けミューテーションテスト。コードをわざと変異させてテストが落ちるかを検証し、AI の書いた「無意味なテスト」を炙り出す | [stryker-mutator.io](https://stryker-mutator.io/) |

---

## 3. 本プロジェクトでの試用・実験候補

本リポジトリ（`penlight-v2`）の実装フェーズにおいて、以下の順でツールを段階的に試行・検証していきます。

1. **第 1 弾（即座に試せる衛生・速度ツール）**:
   - `Biome`（フォーマット & リント）
   - `typos`（変数名・ドキュメントの誤字脱字自動検知）
   - `Knip`（AI が生成したデッドコードの検出と一括削除）
2. **第 2 弾（コード生成・コンテキスト効率化）**:
   - `sqlc`（SQLite 向け型安全 Go リポジトリ自動生成）
   - `Repomix`（AI へのリポジトリ情報パッキング）
3. **第 3 弾（高度な構造制御）**:
   - `ast-grep`（プロジェクト固有のカスタム AST ガードレール）
   - `Stryker`（AI 生成テストの品質スコアリング）
