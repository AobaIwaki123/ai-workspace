# TypeScript 最新 AI 駆動開発ツールチェーンと実践エコシステム (15_typescript_ai_agent_driven_development.md)

本ドキュメントは、2025〜2026年現在における **TypeScript 向け最先端 AI 開発ツール（AI Coding Agent、AST 操作、コード衛生、型安全プロンプト、パターンマッチング）** の実践的なエコシステムを整理し、本プロジェクト（`penlight-v2`）のフロントエンド開発・保守に組み込むための実践仕様書です。

単なる概念論ではなく、**「どのツールを、何の目的で、どう組み合わせて使うのか」** を具体的に規定します。

---

## 1. 2026年最新 TypeScript × AI ツールチェーン一覧マトリクス

AI エージェント（Claude Code / Antigravity / Cursor 等）と人間が協業する上で、コード品質・開発速度・衛生管理を劇的に向上させる 6 大最新ツール群です。

| ツール名 | カテゴリ / 役割 | 解決する課題・AI 協業での用途 | 公式リンク / 出典 |
|---|---|---|---|
| **Knip** | **コード衛生・デッドコード駆除** | AI が量産した未使用の関数・export・孤立ファイル・不要な `npm` パッケージを依存グラフ解析で自動特定・一括除去。**Knip MCP サーバー** を通じて AI 自らにクリーンアップを実行させる | [knip.dev](https://knip.dev/) |
| **ts-morph** | **AST ベース決定論的リファクタリング** | AI の「文字列パターンマッチによる雑な一括置換」を排除。TypeScript Compiler API をラップし、AST（抽象構文木）レベルで型安全な自動リファクタリングや型定義注入を実行 | [ts-morph.com](https://ts-morph.com/) |
| **ts-pattern** | **網羅的パターンマッチング** | AI が書きがちな不完全な `if-else` やフォールスルーバグを防止。Discriminated Union に対する全ケース網羅（Exhaustive Check）を強制し、未処理ルートをコンパイルエラーにする | [github.com/g-loot/ts-pattern](https://github.com/g-loot/ts-pattern) |
| **BAML** | **型安全 AI 構造化出力・プロンプト定義** | Boundary ML 製の AI プログラミング言語。プロンプトを「型付き関数」として扱い、TypeScript クライアントを自動生成。LLM のハルシネーションをパース段階で 100% 遮断 | [boundaryml.com](https://www.boundaryml.com/) |
| **Biome** | **超高速 Linter / Formatter** | Rust 製の超高速解析器。ESLint / Prettier の 20 倍高速（10〜30ms）。AI のコード生成直後にインデントや構文違反を瞬時に自動修正 | [biomejs.dev](https://biomejs.dev/) |
| **Vercel AI SDK (v4+)** | **ストリーミング UI & Generative UI** | React 19 / Next.js に最適化された AI 連携コア。`generateObject` / `streamObject` による Zod/Valibot スキーマ駆動の型安全 UI 構築 | [sdk.vercel.ai](https://sdk.vercel.ai/) |

---

## 2. 各ツールの実践的活用ユースケース

### 2.1 Knip: AI によるコードベース肥大化（Slop）の自動剪定
AI エージェントに新機能を連続して実装させると、「過去の関数を残したまま新しい関数を作る」「使わなくなったユーティリティが放置される」という **技術的負債の急蓄積** が起きます。

#### 導入・実行仕様 (`package.json`)
```json
{
  "devDependencies": {
    "knip": "^5.0.0"
  },
  "scripts": {
    "clean:deadcode": "knip --fix",
    "lint:unused": "knip"
  }
}
```
- **MCP 連携**: AI エージェント（Claude Code / Antigravity）に Knip MCP ツールを渡し、タスク完了時に `knip` を自動実行させ、未使用の export やデッドコードを自律削除させます。

---

### 2.2 ts-morph: プログラムによる精密なコード変換
Go 構造体（正本スキーマ）に変更が入った際や、大規模なコンポーネント移行を行う際、AI にテキスト単位で書き換えさせるとインポート漏れやシンタックスエラーを起こします。

#### 活用例: Go スキーマから Branded Type への自動ラッパー注入
```typescript
import { Project } from 'ts-morph';

const project = new Project();
const sourceFile = project.addSourceFileAtPath('src/types/generated.ts');

// 全ての ID 型 (string) を Branded Types へ自動変換
sourceFile.getTypeAliases().forEach(typeAlias => {
  if (typeAlias.getName().endsWith('Id')) {
    typeAlias.setType(`string & { readonly __brand: unique symbol }`);
  }
});
sourceFile.saveSync();
```
- AI にスクリプトを書かせることで、数千行のコードであっても AST レベルで 1 つの破壊も起こさずに決定論的変換を完了できます。

---

### 2.3 ts-pattern: 出題・回答ステートマシンの網羅性保証
クイズアプリの進行状態（出題中、解答判定中、タイムアップ、スコア表示、オフライン同期待ち）は複雑な状態遷移を持ちます。
`ts-pattern` を用いることで、**AI が「特定状態のハンドリングを忘れるバグ」を型レベルで防止** します。

```typescript
import { match } from 'ts-pattern';

type QuizState =
  | { status: 'idle' }
  | { status: 'question'; questionId: string; timeRemaining: number }
  | { status: 'answered'; isCorrect: boolean; explanation: string }
  | { status: 'offline_queued'; queueCount: number };

// AI が 1 つでも status を書き忘れると TypeScript がコンパイルエラー（.exhaustive()）を出す
const renderQuizView = (state: QuizState) =>
  match(state)
    .with({ status: 'idle' }, () => <StartScreen />)
    .with({ status: 'question' }, ({ timeRemaining }) => <QuestionScreen timer={timeRemaining} />)
    .with({ status: 'answered' }, ({ isCorrect }) => <ResultBadge correct={isCorrect} />)
    .with({ status: 'offline_queued' }, ({ queueCount }) => <OfflineAlert pending={queueCount} />)
    .exhaustive();
```

---

### 2.4 BAML: 型安全な AI プロンプト定義と TS クライアント生成
将来的な拡張として、「メンバーのペンライトカラーの由来・豆知識の自動解説」などの AI 機能を組み込む場合、従来の脆弱な JSON パース（`JSON.parse(res)`）は廃止し、**BAML** を採用します。

#### BAML スキーマ定義例 (`quiz_explainer.baml`)
```baml
class ColorTrivia {
  memberName string
  primaryColor string
  reason string
  concertChant string
}

function GenerateColorTrivia(memberName: string, colors: string[]) -> ColorTrivia {
  client "anthropic/claude-3-5-sonnet"
  prompt #"
    {{ memberName }} のペンライトカラー {{ colors }} について、
    ファン向けの一言解説とライブでのコール・掲げ方のコツを教えてください。
  "#
}
```
- BAML CLI（`baml-cli generate`）により、**100% 型安全な TypeScript クライアント** が自動出力され、フロントエンドから `await baml.GenerateColorTrivia("加藤 史帆", ["スカイブルー", "ブルー"])` のように直接呼び出し可能になります。

---

## 3. AI エージェント自律開発ループ (Self-Healing CI Loop)

AI にコードを書かせる際、以下の 3 段階ゲートキーパーを配置し、すべてパスした場合のみ人間にレビューを依頼します。

```
[AI エージェントがコード生成]
       │
       ▼
1. Biome Check (15ms)  ─── 失敗 ──► `biome check --write` で自動フォーマット
       │ 合格
       ▼
2. TypeScript (tsc)    ─── 失敗 ──► コンパイルエラーログをプロンプトに戻して自己修正
       │ 合格
       ▼
3. Knip Audit          ─── 失敗 ──► `knip --fix` で AI が散らかしたデッドコードを自動掃除
       │ 合格
       ▼
[人間への Pull Request 提出 / レビュー]
```

---

## 4. 参考文献・公式仕様

- [Knip Official Guide - Project Mess Cleaner](https://knip.dev/)
- [ts-morph Documentation - Abstract Syntax Tree Manipulation](https://ts-morph.com/)
- [ts-pattern GitHub Repository](https://github.com/g-loot/ts-pattern)
- [BAML (Boundary ML) - Type-Safe AI Prompt Engineering](https://www.boundaryml.com/)
- [Biome - Fast formatter and linter for JavaScript/TypeScript](https://biomejs.dev/)
- [Vercel AI SDK Core Documentation](https://sdk.vercel.ai/docs/ai-sdk-core)
