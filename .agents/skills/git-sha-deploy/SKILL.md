---
name: git-sha-deploy
description: >-
  Sets up, manages, and verifies GitOps-style GitHub Actions CI/CD workflows that build Docker images tagged with immutable Git commit SHAs and automatically update Kubernetes manifests (k8s/app.yaml). Use this skill when the user asks to implement Git hash tagging CI, automate Kubernetes manifest image tag updates, setup GitHub Container Registry (GHCR) deployment pipelines, or verify end-to-end GitOps deployments.
---

# Git SHA Deploy Skill

本スキルは、Gitコミットの短縮ハッシュ（7桁SHA）を用いてDockerコンテナイメージをビルドし、GitHub Container Registry (GHCR) へPushした上で、Kubernetesマニフェスト（`k8s/app.yaml` 等）内のイメージタグを自動更新・自動コミットするGitOps CI/CDパイプラインの構築と動作確認を自動化します。

---

## ワークフローの概要

```text
[ Git Commit & Push (main) ]
         │
         ▼
[ GitHub Actions (.github/workflows/deploy.yml) ]
         ├─ 1. Git短縮ハッシュ (SHA: 7桁) と小文字イメージ名を取得
         ├─ 2. Docker Buildx (amd64, arm64) でマルチアーキビルド
         ├─ 3. GHCR へ `image:latest` および `image:<sha>` をPush
         ├─ 4. k8s/app.yaml 内の `image: ...:<sha>` を自動書き換え
         └─ 5. [skip ci] 付きでマニフェスト更新を git push origin main
         │
         ▼
[ GitOps (ArgoCD / K8s クラスタ) ]
         └─ 最新SHAタグのPodを自動ローリングアップデート
```

---

## 手順 1: ワークフローのセットアップ

対象リポジトリに `.github/workflows/deploy.yml` を安全に配置します。

```bash
# デフォルトマニフェスト (k8s/app.yaml) を使用する場合
./.agents/skills/git-sha-deploy/scripts/setup-workflow.sh /path/to/target-repo

# 独自のマニフェストパスを指定する場合
./.agents/skills/git-sha-deploy/scripts/setup-workflow.sh -m k8s/deployment.yaml /path/to/target-repo
```

### テンプレートと設計仕様
ワークフローのテンプレート本体は [resources/deploy.yml](resources/deploy.yml) に格納されています。
* **無限ループ防止**: `paths-ignore`（`k8s/**`, `**.md`）およびコミット時の `[skip ci]` を完備。
* **大文字小文字対応**: `tr '[:upper:]' '[:lower:]'` によるGHCR互換リポジトリ名変換。
* **権限設定**: `permissions: contents: write, packages: write` を明示。

詳細なトラブルシューティングや注意点は [references/troubleshooting.md](references/troubleshooting.md) を参照してください。

---

## 手順 2: 変更のコミットとパイプライン発動

ワークフローファイルおよび必要なソースコード・Dockerfileを対象リポジトリにコミットし、`main` へPushします。

```bash
cd /path/to/target-repo
git add .github/workflows/deploy.yml
git commit -m "ci: setup GitOps workflow with Git SHA tagging"
git push origin main
```

---

## 手順 3: 動作確認と検証ループ (Verification Loop)

CI/CDパイプラインの起動確認、完了待ち、マニフェストタグの自動書き換え結果を自動検証します。

```bash
# ワークフローの完了を待機し、マニフェスト更新結果を検証
./.agents/skills/git-sha-deploy/scripts/verify-deploy.sh -w /path/to/target-repo
```

### 検証項目
1. GitHub Actions の最新実行ステータス（Success / In Progress / Failure）。
2. `origin/main` 上の `k8s/app.yaml` に、対象コミットの短縮SHA（例: `:9abbdfe`）が正しく書き込まれているか。
3. 疎通確認（必要に応じてエンドポイントへの curl や `kubectl rollout status`）。
