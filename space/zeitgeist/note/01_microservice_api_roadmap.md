# 01: Zeitgeist マイクロサービス API 化ロードマップ

## 1. 背景と目的
Zeitgeist は単一バイナリの CLI として設計・実装され、高速な並行フェッチとクリーンな構造化 JSON 出力を実現した。
本稿は、本コアエンジン（`pkg/fetcher`, `pkg/driver`）の責務分離を活かし、他サービス（Web UI、AI エージェント、外部スケジューラ、チャット Bot 等）から HTTP 経由でオンデマンドに呼び出せる**マイクロサービス（HTTP API サーバー）へと発展的拡張するための設計ロードマップ**を定義する。

---

## 2. アーキテクチャ設計構想

### 2.1 マルチバイナリ構成
CLI と API サーバーでコアパッケージを 100% 共有し、インターフェース層のみを分離する。

```
cmd/
├── zeitgeist/             # スタンドアロン CLI（実装完了）
└── zeitgeist-server/      # 新規：HTTP API サーバー
pkg/
├── fetcher/               # 並行フェッチ・セマフォ制御（共通コア）
├── driver/                # Adapter パターン実装（共通コア）
├── model/                 # 統一データモデル（共通コア）
├── config/                # 設定ローダー（共通コア）
└── server/                # 新規：HTTP ハンドラー・ミドルウェア・ルーティング
api/
└── openapi.yaml           # 新規：OpenAPI 3.0 スキーマ定義
```

### 2.2 システム連携フロー

```
[クライアント (AI / Web / Bot / Cron)]
                 │ HTTP / JSON
                 ▼
      [cmd/zeitgeist-server]
  ├── GET  /healthz              (Liveness / Readiness)
  ├── GET  /api/v1/sources       (利用可能ソース一覧)
  ├── POST /api/v1/fetch         (オンデマンド並行フェッチ)
  └── GET  /api/v1/feed          (キャッシュ済み最新トピック)
                 │
       ┌─────────┴─────────┐
       ▼                   ▼
[pkg/fetcher]       [pkg/driver]
       │                   │
       └─────────┬─────────┘
                 ▼
        [外部情報ソース群]
```

---

## 3. エンドポイント仕様案（OpenAPI 準拠）

| エンドポイント | メソッド | 機能概要 | 入力パラメータ | 出力 |
|---|---|---|---|---|
| `/healthz` | GET | ヘルスチェック | なし | `{"status":"ok"}` |
| `/api/v1/sources` | GET | 登録済み媒体一覧のメタデータ取得 | `?category=movie` (任意) | `[]Source` |
| `/api/v1/fetch` | POST | 指定媒体のオンデマンド並行フェッチ | JSON Body: `{"sources":["..."], "timeout_seconds":15}` | `Output` (統一JSON) |
| `/api/v1/feed` | GET | 定期巡回キャッシュの高速取得（0ms返却） | `?category=entertainment&limit=10` | `Output` (キャッシュ) |

---

## 4. 段階的ロードマップ

### Phase 1: CLI 基盤の確立（完了）
- [x] Adapter パターンによる `Driver` 抽象化と `RSSDriver` 実装
- [x] Goroutine / セマフォによる高速並行フェッチエンジン
- [x] HTML タグ除去・実体参照デコード・文字数制限によるトークン最適化
- [x] 外部 YAML 設定ファイル駆動アーキテクチャ
- [x] 単一バイナリ CLI の実装およびローカル検証スクリプト

### Phase 2: スキーマ駆動 API サーバーの実装（保留・必要時着手）
- [ ] `api/openapi.yaml` の策定（OpenAPI 3.0）
- [ ] `oapi-codegen` による型および ServerInterface 自動生成
- [ ] `cmd/zeitgeist-server` の実装（Chi または Echo による軽量ルーティング）
- [ ] `GET /healthz`, `GET /api/v1/sources`, `POST /api/v1/fetch` の実装
- [ ] `log/slog` による構造化アクセスログとリカバリーミドルウェア

### Phase 3: バックグラウンド巡回とキャッシュ層
- [ ] インメモリ（または Redis）キャッシュ機能の実装
- [ ] 内部バックグラウンドワーカーによる定期巡回（Cron 式スケジューラ）
- [ ] `GET /api/v1/feed` によるゼロレイテンシ返却
- [ ] Prometheus メトリクス（`/metrics`）によるリクエスト数・レイテンシ・外部取得成功率の可観測性担保

### Phase 4: コンテナ化 ＆ GitOps（Kubernetes）デプロイ
- [ ] マルチステージビルドによる軽量 Dockerfile（Distroless ベース）
- [ ] GitHub Actions による GHCR へのコンテナイメージ自動ビルド・Push
- [ ] Kubernetes マニフェスト（Deployment, Service, Cloudflare Tunnel Ingress）の作成
- [ ] ArgoCD による GitOps 同期と本番稼働検証

---

## 5. 参考文献・関連ドキュメント
- [ADR-0001: Zeitgeist CLI アーキテクチャ選定](../adr/0001-zeitgeist-architecture.md)
- OpenAPI Specification (v3.0.3): https://spec.openapis.org/oas/v3.0.3
- Deep Inversion of Control & Clean Architecture in Go: Martin, R. C. (2017). *Clean Architecture*. Prentice Hall.
