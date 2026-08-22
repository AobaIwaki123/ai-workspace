# ISUCON サンドボックス アーキテクチャ & 複製ガイド

ISUCON 模擬環境（ローカル Docker Compose / Kubernetes クラスタ）の構成概要と、複製・運用のリファレンスです。

---

## 1. 2つのデプロイ形態

| 形態 | 対象環境 | 特徴 | 起動コマンド |
| :--- | :--- | :--- | :--- |
| **Local Sandbox** | ローカルマシン (Docker Compose) | 外部依存なし、手元のPCだけで即座に測定サイクル（alp, pt-query, pprof）を体験 | `make up && make bench` |
| **Kubernetes Sandbox** | k8s クラスタ (ArgoCD / GitOps) | journee スタイル。Ingress (Cloudflare Tunnel) 経由で外部公開、メンバーごとの個別環境量産 | `make deploy && make bench` |

---

## 2. Kubernetes サンドボックスのディレクトリ構造 (journee-style)

```
<target-dir>/
├── README.md                     # デプロイ手順書
├── Makefile                      # 測定・ベンチマーク実行コマンド
├── argocd/
│   └── app.yml                   # ArgoCD Application マニフェスト
├── manifests/
│   ├── kustomization.yml         # Kustomize エントリポイント
│   ├── app-deployment.yml        # Go アプリケーション (:8000, :6060 pprof)
│   ├── app-service.yml           # Go アプリ Service
│   ├── mysql-configmap.yml       # my.cnf (スローログ) & 00_schema.sql (初期データ)
│   ├── mysql-deployment.yml      # MySQL 8.0 Deployment
│   ├── mysql-service.yml         # MySQL Service (:3306)
│   ├── nginx-configmap.yml       # nginx.conf (LTSVログ)
│   ├── nginx-deployment.yml      # Nginx Deployment
│   ├── nginx-service.yml         # Nginx Service (:80)
│   ├── ingress.yml               # Cloudflare Tunnel Ingress
│   └── benchmarker-configmap.yml # クラスタ内ベンチマーク Job & スクリプト
└── scripts/
    └── create-branch-infra.sh    # メンバー/ブランチ別環境の自動生成スクリプト
```

---

## 3. メンバーごとの分離環境量産メカニズム

`create-branch-infra.sh <name>` を実行すると:
1. `manifests/` が `manifests-<name>/` に複製され、Ingress のホスト名が `isucon-<name>.aooba.net` に自動置換されます。
2. `argocd/app.yml` が `argocd-<name>/app.yml` に複製され、Application 名が `isucon-<name>` に置換されます。
3. これにより、1つのクラスタ内で複数人が同時に互いのデータを干渉せずに演習できます。
