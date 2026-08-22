# カスタムサブエージェント一覧 (Subagents)

本リポジトリで利用可能な専門サブエージェントの一覧と役割定義です。

---

## 1. `isucon-expert` (ISUCON チューニング専門エージェント)
- **概要**: ISUCONのWebパフォーマンスチューニング（alp / pt-query-digest / pprof 解析、SQLインデックス設計、N+1解消、インメモリキャッシュ、ミドルウェア設定、ベンチマーク評価）を専門に担当するエージェント。
- **得意領域**:
  - `alp` によるエンドポイント集計・ボトルネック特定
  - `pt-query-digest` によるスロークエリ特定・複合インデックス設計
  - Go (`pprof`, `singleflight`, `go-json`) / TypeScript (`PM2`, `mysql2`) の高速化
  - 終了前プロトコル（全ログOFF、再起動試験）

---

## 2. `stacked-pr-assistant` (Stacked PR / Git 運用専門エージェント)
- **概要**: 巨大なタスクを小さく分割した一連のPR（Stacked PR）の作成・親ブランチ追従（rebase/restack）・Base Branch更新を自律的に行うエージェント。
- **得意領域**:
  - 親ブランチを `--base` に指定したPR作成
  - 親更新時の子ブランチ自動 rebase & `--force-with-lease`
  - 親PRマージ後の `gh pr edit --base main`
