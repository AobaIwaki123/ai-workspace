# ISUCON k8sへのデプロイ方法

お持ちの Kubernetes クラスタに ISUCON 模擬環境（Nginx + Go App + MySQL + Benchmarker）をデプロイし、誰でもブラウザや外部からアクセス・測定・ベンチマークを実行できる環境の構築手順です。

---

## 1. 手動デプロイ (kubectl / kustomize)

```sh
# 全マニフェストの一括適用
kubectl apply -k isucon/k8s/manifests/
```

---

## 2. ArgoCD でのデプロイ

```sh
# ArgoCD アプリケーションの登録
argocd app create -f isucon/k8s/argocd/app.yml --upsert

# 状態確認 & 同期
argocd app get isucon-dev
argocd app sync isucon-dev   # 手動で今すぐ同期したい時
```

---

## 3. ブランチ・メンバーごとの個別環境作成

チームメンバー各自が独立してチューニングやベンチマークを行えるよう、ブランチやメンバー名（例: `alice`, `feature-index` 等）ごとに独立したマニフェストおよび ArgoCD 設定を生成できます。

```sh
# ブランチ用環境マニフェストの生成
./isucon/k8s/scripts/create-branch-infra.sh <branch-name>
```

同一 namespace 内またはホスト名でユニークでなければならない値（`isucon-<branch>.aooba.net` 等）が自動的に設定されます。

---

## 4. ベンチマーク & 測定の実行

付属の [Makefile](./Makefile) を使用して、クラスタ内での負荷テストやログ集計を行えます。

```sh
cd isucon/k8s

# ベンチマーク実行 (Kubernetes Job)
make bench

# Nginx アクセスログ集計 (alp)
make alp

# MySQL スロークエリ集計 (pt-query-digest)
make slow

# pprof プロファイラへのポートフォワード (FlameGraph確認)
make pprof
```
