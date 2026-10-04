# Cloudflare 次世代統合CLI「cf」の機能概要・アーキテクチャ・移行ガイド

## 1. 概要 (Overview)

2026年9月28日、Cloudflareは新しい統合コマンドラインインターフェース（CLI）である **`cf`**（別名 **`cloudflare`**）のオープンベータ版を公開しました。

これまでCloudflareの開発者は、WorkersやPagesの開発・デプロイには `wrangler` を使用し、DNSレコード、WAFルール、Zero Trust / Access、ドメイン管理といったインフラ領域の操作にはWebダッシュボード、Terraform、または個別のREST API / SDKを使い分ける必要がありました。

`cf` はこれらを完全に単一のCLIへ統合し、Cloudflareの公開APIが提供する **3,000以上の全操作** を直接実行できるように設計された次世代ツールです。また、近年のAIコーディングエージェントの普及を踏まえ、人間だけでなくAIエージェントによる自動操作を前提とした「Agent-Centric（エージェント指向）」のアーキテクチャを採用しています。

---

## 2. 開発背景とアーキテクチャ

### 2.1 Wranglerの限界とプラットフォーム統合の必要性
従来の公式CLIである `wrangler` は、Cloudflare Workersのエコシステムに特化して進化してきました。しかし、対応しているAPI操作は約280種類にとどまり、プラットフォーム全体の約1割未満に過ぎませんでした。エッジコンピューティング（Workers、D1、R2）とネットワーク・セキュリティ基盤（DNS、WAF、Zero Trust）の境界が曖昧になる中で、インフラ全体を一貫して宣言的かつコマンドラインから扱えるツールの需要が急速に高まりました。

### 2.2 自動生成エンジン「Forge」によるAPI完全追従
`cf` は、Cloudflareが内部で整備したSDKおよびCLI自動生成パイプライン **「Forge」** を基盤としています。OpenAPI仕様書からCLIコマンド群を自動生成することにより、APIの新機能や仕様変更に対して遅延なくCLIが更新され、常に最新のプラットフォーム機能を利用可能にするアーキテクチャを実現しています。

---

## 3. 主要機能と「できること」

### 3.1 プラットフォーム全リソースの統合管理
`cf` 1つで、開発ライフサイクルからネットワーク・セキュリティの運用まで完結します。

| カテゴリ | 対象サービス・リソース | 主なCLI操作 |
|---|---|---|
| **コンピューティング** | Workers, Pages, Workflows | プロジェクト初期化、ローカル実行、ビルド、デプロイ、ログストリーミング |
| **ストレージ & DB** | D1 (SQL), R2 (オブジェクト), KV, Vectorize (ベクトルDB), Hyperdrive | データベース作成、マイグレーション実行、バケット管理、データ読み書き |
| **DNS & ドメイン** | Authoritative DNS, Registrar | ゾーン一覧、A/AAAA/CNAME/TXT等のレコード登録・更新・削除、DNSSEC設定 |
| **セキュリティ & WAF** | Web Application Firewall, Turnstile, Rate Limiting | WAFカスタムルールの適用、CAPTCHA代替のTurnstileウィジェット発行、ボット保護 |
| **Zero Trust** | Cloudflare Access, Gateway, Cloudflare Tunnel | トンネル接続の確立、アプリケーション認証ポリシーの更新、ルーティング管理 |

### 3.2 AIエージェント最適化 (Agent-Centric Features)
AIエージェント（Antigravity、Claude Code、Cursor等）との協業を前提とした以下の機能が備わっています。

1. **自然言語によるコマンド検索 (`cf cli search`)**
   3,000以上の操作から目的のコマンドを瞬時に特定するため、自然言語クエリによる逆引き機能を内蔵しています。
   ```bash
   cf cli search "create a D1 database"
   cf cli search "add a DNS CNAME record pointing to my app"
   ```
2. **一貫したJSON出力**
   デフォルトで構造化されたJSON形式で結果を返すため、AIエージェントやシェルスクリプトによるパースエラーを最小化します。
3. **自己説明的なヘルプとスキーマ**
   すべてのコマンドが引数の型、必須フラグ、期待されるリクエストボディの仕様を標準形式で提供します。

### 3.3 TypeScript設定ファイル (`cloudflare.config.ts`) への移行
従来の静的な `wrangler.toml` や `wrangler.jsonc` を廃止し、TypeScriptによるコードベースの設定ファイル **`cloudflare.config.ts`** を採用しました。

- **IDE補完と型安全性:** バインディング名やトリガーの記述ミスをコードエディタの静的解析で即座に検出。
- **動的ロジックの記述:** 環境変数による条件分岐や設定値の動的生成をNode.js環境のコードとして記述可能。
- **型定義の自動生成 (`cf workers types`):** `cloudflare.config.ts` の内容から、ワーカーコード内で参照する環境型定義（`Env`）を自動抽出・同期。

### 3.4 Vite標準統合による高速ローカル開発
内部のバンドラ・ローカル開発基盤として **Vite** が標準採用されています。
- 高速なホットモジュールリプレースメント (HMR)
- ソースマップの完全サポート
- Web標準API（Fetch, Request, Response, Streams）のエミュレーション向上

---

## 4. Wranglerからの移行方針 (Migration Guide)

### 4.1 自動マイグレーションツール (`cf migrate`)
既存の `wrangler` プロジェクトのルートディレクトリで以下のコマンドを実行することで、既存の `wrangler.toml` または `wrangler.jsonc` を解析し、等価な `cloudflare.config.ts` を自動生成します。

```bash
cf migrate
```

### 4.2 設定ファイルの対応関係
静的なTOML設定が、型定義されたTypeScriptオブジェクトのエクスポートへと置き換わります。

```typescript
// cloudflare.config.ts の構成イメージ
import { defineConfig } from "cf";

export default defineConfig({
  name: "my-edge-service",
  main: "src/index.ts",
  compatibilityDate: "2026-10-01",
  compatibilityFlags: ["nodejs_compat"],
  d1Databases: [
    {
      binding: "DB",
      databaseId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    }
  ],
  r2Buckets: [
    {
      binding: "STORAGE",
      bucketName: "my-assets"
    }
  ]
});
```

### 4.3 ライフサイクルとサポートポリシー
- **オープンベータ期間:** 2026年9月下旬より開始。フィードバックの収集と機能拡張中。
- **Wranglerの並行サポート:** Cloudflareは、`cf` が正式版（GA）となった後も最低18ヶ月間は `wrangler` のセキュリティパッチおよび重大バグ修正を継続すると発表しています。
- **推奨事項:** 既存プロダクションは段階的に `cf migrate` を検証し、新規作成するプロジェクトは最初から `cf` を採用することが推奨されます。
- **実行環境要件:** Node.js 22.18以上（現在、Bunランタイムによる `cloudflare.config.ts` の直接読み込みは一部制約あり）。

---

## 5. 基本コマンドリファレンス

### 5.1 インストール
グローバルパッケージマネージャ経由でインストールします。

```bash
# npm
npm install --global cf

# yarn / pnpm / bun
yarn global add cf
pnpm add --global cf
bun add --global cf
```

※システム上にすでにCloud Foundry CLI等の `cf` コマンドが存在する場合は、別名コマンド **`cloudflare`** が自動的に利用可能です。

### 5.2 認証
```bash
# ブラウザ経由でのOAuthログイン
cf auth login

# 現在のログインアカウント・権限スコープの確認
cf auth whoami

# ログアウト
cf auth logout
```

### 5.3 開発・ビルド・デプロイ
```bash
# 新規プロジェクトのスキャフォールディング
cf init <project-name>

# ローカル開発サーバー起動（Viteベース）
cf dev

# プロダクション向けバンドル・ビルド
cf build

# Cloudflareネットワークへのデプロイ
cf deploy

# 型定義の更新
cf workers types
```

### 5.4 インフラ操作例
```bash
# DNSレコードの追加
cf dns records create --zone-id <ZONE_ID> --type CNAME --name app --content my-service.workers.dev --proxied

# D1データベースの作成
cf d1 create my-production-db

# R2バケット一覧の取得
cf r2 buckets list
```

---

## 6. 一次情報および権威ある参照リンク (Authoritative Sources)

- [Cloudflare Blog - Introducing cf: The unified CLI for Cloudflare](https://blog.cloudflare.com/)
- [Cloudflare Documentation - Command Line Interface (CLI)](https://developers.cloudflare.com/)
- [Cloudflare Workers Documentation - Configuration via cloudflare.config.ts](https://developers.cloudflare.com/workers/)
- [GitHub - cloudflare/cf (Official Repository)](https://github.com/cloudflare)
