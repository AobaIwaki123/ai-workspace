# GitOps SHA Tagging CI/CD Troubleshooting & Best Practices

本ドキュメントは、Gitコミット短縮SHAを用いてコンテナイメージをビルドし、Kubernetesマニフェスト（`k8s/app.yaml` 等）内のタグを自動書き換え・コミットするGitOps CI/CDパイプラインにおいて蓄積された知見と失敗防止策をまとめたリファレンスです。

---

## 1. 無限ループ防止 (Loop Prevention)

### 問題
マニフェストファイルを自動コミットして `git push origin main` すると、再度 `on: push: branches: [main]` が発火し、ビルドとコミットの無限ループが発生する。

### 対策（二重防衛）
1. **`paths-ignore` の設定**:
   ```yaml
   on:
     push:
       branches: [main]
       paths-ignore:
         - 'k8s/**'
         - '**.md'
   ```
2. **コミットメッセージへの `[skip ci]` 付与**:
   ```yaml
   git commit -m "chore(deploy): update deployment image to ${SHORT_SHA} [skip ci]"
   ```

---

## 2. GHCR リポジトリ名の大文字小文字問題

### 問題
GitHubのユーザー名やリポジトリ名に大文字が含まれる場合（例: `AobaIwaki123/atmo`）、Docker/OCIの仕様により大文字を含むタグは拒否される（`invalid reference format: repository name must be lowercase`）。

### 対策
ワークフロー内で必ず小文字変換（`tr '[:upper:]' '[:lower:]'`）を行う：
```bash
IMAGE_LOWER=$(echo "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}" | tr '[:upper:]' '[:lower:]')
```

---

## 3. GitHub Actions 権限設定 (Permissions)

### 問題
`GITHUB_TOKEN` のデフォルト権限では、マニフェスト更新の `git push` や GHCR へのイメージ Push が拒否される（`Permission denied to github-actions[bot]` または `403 Forbidden`）。

### 対策
ワークフロー最上位に以下の権限を明記する：
```yaml
permissions:
  contents: write
  packages: write
```

---

## 4. `sed -i` のOS互換性とマッチング精度

### 問題
macOS（BSD）とLinux（GNU）で `sed -i` の引数仕様が異なり、CI環境（Ubuntu）とローカル検証で挙動が変わる。また、正規表現が甘いと他のイメージ行まで誤って書き換えてしまう。

### 対策
CI（Ubuntu）上では GNU sed 用の構文とし、リポジトリ名を含む厳密な正規表現で書き換える：
```bash
sed -i "s|image: .*/${REPOSITORY_NAME}:.*|image: ${IMAGE_LOWER}:${SHORT_SHA}|g" k8s/app.yaml
```
変更後の差分確認とコミット条件分岐：
```bash
git add k8s/app.yaml
if git diff --staged --quiet; then
  echo "No manifest changes to commit."
else
  git commit -m "chore(deploy): update deployment image to ${SHORT_SHA} [skip ci]"
  git push origin main
fi
```
