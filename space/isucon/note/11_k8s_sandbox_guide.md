# Kubernetes クラスタで動かす ISUCON サンドボックスガイド (11_k8s_sandbox_guide.md)

`~/journee/k8s/` の GitOps / ArgoCD / Ingress 運用設計をベースに、お持ちの Kubernetes クラスタに ISUCON 模擬環境（Nginx + Go App + MySQL + Benchmarker）をデプロイし、**チームメンバーや外部の人が誰でも自由にアクセス・測定・ベンチマークを実行できる環境**を構築するガイドです。

---

## 🏛️ ディレクトリ構成 (journee-style)

```
isucon/k8s/
├── README.md                     # デプロイ手順書
├── Makefile                      # 測定・ベンチマーク実行ヘルパー
├── argocd/
│   └── app.yml                   # ArgoCD Application マニフェスト (isucon-dev)
├── manifests/
│   ├── kustomization.yml         # Kustomize エントリポイント
│   ├── app-deployment.yml        # Go アプリ Deployment
│   ├── app-service.yml           # Go アプリ Service (:8000, :6060 pprof)
│   ├── mysql-configmap.yml       # my.cnf (スローログ) & 00_schema.sql (初期データ)
│   ├── mysql-deployment.yml      # MySQL 8.0 Deployment
│   ├── mysql-service.yml         # MySQL Service (:3306)
│   ├── nginx-configmap.yml       # nginx.conf (LTSVログ)
│   ├── nginx-deployment.yml      # Nginx Deployment
│   ├── nginx-service.yml         # Nginx Service (:80)
│   ├── ingress.yml               # Ingress (cloudflare-tunnel, isucon.aooba.net)
│   └── benchmarker-configmap.yml # bench.sh スクリプト & Benchmarker Job
└── scripts/
    └── create-branch-infra.sh    # ブランチ/ユーザー別個別環境の自動生成スクリプト
```

---

## 🚀 デプロイ手順

### 1. 手動デプロイ (kubectl / Kustomize)
```bash
cd isucon/k8s
make deploy
```

### 2. ArgoCD による継続的デプロイ (GitOps)
```bash
argocd app create -f isucon/k8s/argocd/app.yml --upsert
argocd app sync isucon-dev
```

---

## 🏎️ ベンチマーク & 測定ツールの実行

付属の `Makefile` からワンコマンドで測定できます。

```bash
cd isucon/k8s

# ① ベンチマークJobを実行 (リアルタイムログ追従 & スコア表示)
make bench

# ② Nginx アクセスログ集計 (alp で合計時間ワーストを特定)
make alp

# ③ MySQL スロークエリ集計 (pt-query-digest で重いSQLを特定)
make slow

# ④ pprof による FlameGraph 可視化
make pprof
# ブラウザで http://localhost:6060/debug/pprof/ を開く
```

---

## 👥 ブランチ・メンバーごとの個別環境量産

チームメンバー（例: `alice`, `bob`）が独立してチューニング・ベンチマークを行いたい場合、以下のスクリプトで専用のマニフェストと ArgoCD 設定を生成できます。

```bash
# メンバー "alice" 用の環境を作成
./isucon/k8s/scripts/create-branch-infra.sh alice

# Namespace 作成
kubectl create namespace isucon-alice --dry-run=client -o yaml | kubectl apply -f -

# 生成された専用マニフェストをデプロイ
kubectl apply -k isucon/k8s/manifests-alice/
# または ArgoCD で登録
argocd app create -f isucon/k8s/argocd-alice/app.yml --upsert
```

これにより、`isucon-alice.aooba.net` のような専用ホスト名で各自が自由に検証できます！
