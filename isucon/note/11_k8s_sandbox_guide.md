# Kubernetes クラスタで動かす ISUCON サンドボックスガイド (11_k8s_sandbox_guide.md)

お持ちの Kubernetes（k8s）クラスタに ISUCON 模擬環境（Nginx + Go App + MySQL + Benchmarker）をデプロイし、**チームメンバーや外部の人が誰でも自由にアクセス・測定・ベンチマークを実行できる環境**を構築するガイドです。

---

## 🏛️ Kubernetes 上のアーキテクチャ

```mermaid
graph TD
    Client[外部ユーザー / ブラウザ] -->|NodePort: 30080 / Ingress| NginxSvc[Service: nginx]
    NginxSvc --> NginxPod[Pod: nginx (LTSVログ)]
    NginxPod --> AppSvc[Service: app]
    AppSvc --> AppPod[Pod: app-go (:8000 / :6060 pprof)]
    AppPod --> MySQLSvc[Service: mysql]
    MySQLSvc --> MySQLPod[Pod: mysql (スローログ)]

    BenchJob[Job: isucon-benchmarker] -->|ClusterIP 経由で負荷生成| NginxSvc
```

---

## 🚀 クイックスタート手順

### 1. アプリイメージのビルド
```bash
cd isucon/k8s
make build-image
```
> [!NOTE]
> - `kind` をお使いの場合: `kind load docker-image isucon-app:latest`
> - `minikube` をお使いの場合: `minikube image load isucon-app:latest`
> - リモートクラスタ（EKS, GKE, オンプレ等）の場合: お手持ちのContainer Registryにプッシュし、`app/deployment.yaml` の `image` を更新してください。

### 2. クラスタへのデプロイ
```bash
make deploy
```
Namespace `isucon` が作成され、MySQL（初期データ自動投入）、Go App、Nginx が起動します。

### 3. 稼働状態の確認
```bash
make status
```

---

## 🏎️ ベンチマーク & 測定ツールの実行

### ① クラスタ内ベンチマーク実行 (`make bench`)
Kubernetes Job（`isucon-benchmarker`）がクラスタ内から高速に並行負荷を生成し、リアルタイムでスコアを集計・表示します。

```bash
make bench
```

### ② Nginx アクセスログ集計 (`make alp`)
Podから直接アクセスログを取得して `alp` で重いエンドポイントを特定します。

```bash
make alp
```

### ③ MySQL スロークエリ集計 (`make slow`)
MySQL Pod内のスロークエリログを取得して `pt-query-digest` で解析します。

```bash
make slow
```

### ④ pprof プロファイラへのアクセス (`make pprof`)
ローカルマシンからポートフォワードし、ブラウザで FlameGraph を閲覧できます。

```bash
make pprof
# ブラウザで http://localhost:6060/debug/pprof/ を開く
```

---

## 👥 チームマルチプレイ（メンバーごとの個人環境の量産）

Kustomize の `namespace` を変更することで、**1つのクラスタ上にメンバーごとの完全分離環境（例: `isucon-alice`, `isucon-bob`）を瞬時に作成**できます。

```bash
# メンバー A 専用の環境を作成
kubectl create namespace isucon-alice
kubectl apply -k . -n isucon-alice

# メンバー A の環境でベンチマーク
kubectl apply -f benchmark/job.yaml -n isucon-alice
```
これにより、3人が互いのコード変更やDBデータを壊すことなく、各自のペースでチューニング演習を行えます！
