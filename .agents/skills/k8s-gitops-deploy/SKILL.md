---
name: k8s-gitops-deploy
description: >-
  Sets up end-to-end Kubernetes deployments with Cloudflare Tunnel Ingress manifests, Git short SHA Docker image CI/CD pipelines, ArgoCD GitOps registration, and full verification. Use this skill when asked to deploy applications to Kubernetes, scaffold Cloudflare Ingress manifests (cloudflare-tunnel), set up immutable Git SHA image tagging CI workflows with automated manifest updates, register ArgoCD applications, or verify end-to-end deployment rollout and external HTTPS connectivity.
---

# Kubernetes GitOps Deployment Skill

Kubernetes アプリケーションのデプロイに必要な **Cloudflare Tunnel Ingress を含むマニフェスト設計**、**Git短縮コミットハッシュ（7桁SHA）を用いたコンテナビルド & 自動マニフェスト更新 CI/CD**、**ArgoCD による自動同期**、および **外部 HTTPS 疎通を含む一気通貫の動作検証** を自動化・標準化するスキルです。

---

## 全体デプロイフロー

```text
[ 1. マニフェスト作成 (k8s/app.yaml) ]
     ├─ Namespace, Deployment, Service
     └─ Ingress (ingressClassName: cloudflare-tunnel, *.aooba.net)
          │
          ▼
[ 2. CI/CD パイプライン配置 (.github/workflows/deploy.yml) ]
     ├─ Docker Buildx (amd64, arm64) によるマルチアーキビルド
     ├─ GHCR へ image:<sha> をプッシュ
     └─ k8s/app.yaml のイメージタグを自動置換 & [skip ci] でプッシュ
          │
          ▼
[ 3. GitOps 同期 (ArgoCD) ]
     └─ リポジトリ変更を検知しクラスタへ自動ローリングアップデート
          │
          ▼
[ 4. 一気通貫の動作検証 (scripts/verify-deploy.sh) ]
     ├─ GitHub Actions 完了確認
     ├─ マニフェスト SHA 更新確認
     ├─ Pod ロールアウト確認 (kubectl rollout status)
     └─ 外部 HTTPS 疎通確認 (curl -sI https://<host>/)
```

---

## 手順 1: Cloudflare Ingress 完備マニフェストの生成

対象リポジトリの `k8s/app.yaml` に、Namespace、Deployment、Service、Cloudflare Ingress を一括生成します。

```bash
# 自動生成ヘルパーを実行
./.agents/skills/k8s-gitops-deploy/scripts/generate-manifest.sh \
  --name <app-name> \
  --port 8080 \
  --host <app-name>.aooba.net \
  /path/to/target-repo
```

### マニフェストの要点（Cloudflare Ingress）
Cloudflare Ingress は `ingressClassName: cloudflare-tunnel` を指定し、クラスタ内の `cloudflare-tunnel-ingress-controller` アノテーションを付与します。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <app-name>
  annotations:
    cloudflare-tunnel-ingress-controller.strrl.dev/backend-protocol: "http"
    cloudflare-tunnel-ingress-controller.strrl.dev/tunnel-name: "cf-tunnel-ingress-controller"
spec:
  ingressClassName: cloudflare-tunnel
  rules:
    - host: <app-name>.aooba.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <app-name>
                port:
                  number: 80
```

詳細なアノテーション仕様や TLS 設定は [references/cloudflare-ingress.md](references/cloudflare-ingress.md) を参照してください。

---

## 手順 2: Git SHA デプロイ CI ワークフローの配置

対象リポジトリに `.github/workflows/deploy.yml` を配置します。

```bash
./.agents/skills/k8s-gitops-deploy/scripts/setup-workflow.sh /path/to/target-repo
```

### ワークフローの設計仕様
テンプレート本体は [resources/deploy.yml](resources/deploy.yml) です。
- **不変タグ運用**: コミットハッシュ（`git rev-parse --short HEAD`）で GHCR へプッシュ。
- **マニフェスト自動更新**: `sed` で `k8s/app.yaml` のタグを置換し、`github-actions[bot]` として自動コミット。
- **無限ループ防止**: `paths-ignore`（`k8s/**`, `**.md`）とコミット時の `[skip ci]` を完備。
- **大文字正規化**: GHCR 仕様に従い、GitHub ユーザー名・リポジトリ名を小文字化。

---

## 手順 3: ArgoCD への登録（GitOps 化）

リポジトリ変更をクラスタに自動反映させるため、ArgoCD Application を登録します。

```bash
# クラスタへ直接適用する場合
./.agents/skills/k8s-gitops-deploy/scripts/setup-argocd.sh --apply /path/to/target-repo
```

---

## 手順 4: デプロイ発動と変更の Push

ソースコード、Dockerfile、`k8s/app.yaml`、ワークフローをコミットしてプッシュします。

```bash
cd /path/to/target-repo
git add .
git commit -m "feat(deploy): setup k8s manifest and Git SHA deploy CI"
git push origin main
```

---

## 手順 5: 一気通貫の動作検証

CI の実行から Cloudflare 経由の外部疎通まで、すべて自動で検証します。

```bash
./.agents/skills/k8s-gitops-deploy/scripts/verify-deploy.sh \
  --watch \
  --check-k8s \
  --check-ingress \
  /path/to/target-repo
```

検証項目:
1. **GitHub Actions 監視**: ビルドジョブが正常終了（`success`）するまで待機。
2. **Git タグ更新検証**: `origin/main` の `k8s/app.yaml` 内イメージタグがコミット SHA と一致することを確認。
3. **Pod ロールアウト検証**: `kubectl rollout status` で新イメージの Pod が Ready になることを確認。
4. **Cloudflare 疎通検証**: `https://<app>.aooba.net` へ HTTPS リクエストを送り、HTTP 200/リダイレクトが返ることを確認。

トラブルシューティング知見は [references/troubleshooting.md](references/troubleshooting.md) を参照してください。
