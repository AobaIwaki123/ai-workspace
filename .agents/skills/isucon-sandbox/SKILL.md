---
name: isucon-sandbox
description: >-
  Scaffold, replicate, and manage ISUCON sandbox environments for local Docker Compose
  and Kubernetes clusters (journee-style GitOps with ArgoCD, Cloudflare Ingress,
  and multi-user branch isolation). Use when setting up new ISUCON practice sandboxes,
  replicating environments for team members, or running profiling analysis.
---

# ISUCON Sandbox Skill

本スキルは、ISUCON 模擬練習環境（Nginx + Go/Node App + MySQL + Benchmarker）をローカル（Docker Compose）または Kubernetes クラスタ（journee スタイル / GitOps）へ即座に複製・構築・運用するための手順およびヘルパースクリプトを提供します。

---

## 1. 発動トリガー

以下のような状況でこのスキルを実行します:
- ユーザーが「ISUCONの練習環境を立ち上げて」「サンドボックスを複製して」「新しいメンバー用の環境を作って」と指示した時
- ローカルマシン上で Docker Compose を使った測定ハンズオン環境を新規作成したい時
- お手持ちの Kubernetes クラスタに ArgoCD / Cloudflare Ingress 対応の ISUCON 環境をデプロイしたい時
- チームメンバーごとの個別分離環境（`manifests-<name>`, `argocd-<name>`）を量産したい時

---

## 2. 実行手順

付属のスクリプト群（[scripts/](./scripts/)）を使用して操作します。

### パターンA: ローカル模擬環境（Docker Compose）の生成・起動

```bash
# 1. 指定ディレクトリにローカル環境一式を生成
./.agents/skills/isucon-sandbox/scripts/setup-local.sh ./isucon-sandbox-local

# 2. 起動 & ベンチマーク
cd ./isucon-sandbox-local
make up
make bench

# 3. 測定結果の集計
make alp     # Nginxアクセスログ解析
make slow    # MySQLスロークエリ解析
```

---

### パターンB: Kubernetes クラスタ環境（journee-style）の生成・デプロイ

```bash
# 1. journeeスタイルの k8s マニフェスト一式を生成
./.agents/skills/isucon-sandbox/scripts/setup-k8s.sh ./isucon-k8s isucon.aooba.net

# 2. クラスタへのデプロイ
cd ./isucon-k8s
make deploy

# 3. クラスタ内ベンチマーク & 測定
make bench
make alp
make slow
```

---

### パターンC: チームメンバー/ブランチごとの個別環境量産

1つのクラスタ上に、メンバー別の独立した Namespace / Ingress / ArgoCD 設定を瞬時に作成します。

```bash
# "alice" 専用の環境を生成
./.agents/skills/isucon-sandbox/scripts/create-env.sh ./isucon-k8s alice

# 専用環境のデプロイ
kubectl apply -k ./isucon-k8s/manifests-alice/
```

---

### パターンD: 測定ログの一括解析

```bash
# ローカル環境のログ解析
./.agents/skills/isucon-sandbox/scripts/profile.sh local ./isucon-sandbox-local

# Kubernetes クラスタのログ解析
./.agents/skills/isucon-sandbox/scripts/profile.sh k8s isucon
```

---

## 3. 詳細リファレンス

- 各種設定パラメータやアーキテクチャの詳細は [references/sandbox-architecture.md](./references/sandbox-architecture.md) を参照してください。

---

## 4. 検証ステップ

作業後は必ず以下を実行して状態を確認します:
1. ローカルの場合: `docker compose ps` で `nginx`, `app`, `mysql` が正常稼働（healthy）していることを確認。
2. Kubernetes の場合: `kubectl get pods,svc,ingress -n isucon` で全リソースが Running 状態になっていることを確認。
3. `make bench` を実行し、スコアが正常に出力されることを確認。
