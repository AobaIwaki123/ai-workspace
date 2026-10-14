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

---

## 5. ビルド最適化の原則: 「積極的な高速化」ではなく「不要な処理の徹底排除」

### 原則
- **過剰な高速化テクニックの罠**: 複雑なマルチレイヤーキャッシュや外部キャッシュストレージの導入は、キャッシュ破損（Cache Invalidation 漏れ）やキャッシュ送受信自体のオーバーヘッドを生み、ビルドの不安定化や所要時間悪化（逆効果）を招くことがあります。そのため「小手先の積極的な高速化」は行いません。
- **不要な処理の徹底排除**: 一方で、**「クラスタで実際には利用されない不要な処理」は完全に無駄であるため、極力排除**します。

### 実例: 不要な QEMU エミュレーションの排除
- `platforms: linux/amd64,linux/arm64` を指定すると、GitHub Actions（x86_64）上で `arm64` 向けビルドが QEMU CPU ソフトウェアエミュレーションで実行され、ビルド時間の 80% 以上（2〜3分）を消費します。
- しかし、自前 Kubernetes クラスタ（`kubectl get nodes -o wide`）を確認すると、全ワーカーノードが `amd64` であり `arm64` ノードが存在しないケースが多くあります。
- クラスタに存在しないアーキテクチャのビルドステップ（QEMU 等）を削除し、実際の稼働環境（`linux/amd64`）に絞ることで、安全かつ劇的な時間短縮（3分30秒 ➔ 1分以内）が得られます。

---

## 6. 位置情報（GPS）連携時の空間グリッド丸めキャッシュ設計

### 問題
- 端末（Web ブラウザやスマートフォン）から GPS 座標を受け取って気象・周辺データを返す場合、生の浮動小数点座標（`35.681234, 139.767189` 等）をそのままキャッシュキーにすると、GPS の微小な揺れや歩行によってキャッシュヒット率がほぼ 0% に低下し、外部 API のレートリミットを急速に圧迫します。

### 対策
1. **空間グリッド丸め（Spatial Grid Key）**:
   - 気象データや予報モデルの空間メッシュ（数km四方）に合わせ、座標を **小数点第2位（約 1.1km メッシュ）に丸めてキー化** します。
   - 例: `lat: 35.681234, lon: 139.767189` ➔ キー `"35.68,139.77"`
2. **インメモリ TTL キャッシュ**:
   - Go サーバー内で `sync.RWMutex` + マップによる TTL（10〜15分）キャッシュを保持します。
   - 同一生活圏のユーザーや歩行中の同一ユーザーからのリクエストをインメモリ（0.06s）で即座に返却します。
3. **クライアント側のシームレス・フォールバック**:
   - Flutter / Web 側では標準 Geolocation API（`geolocator`）で OS/Apple 標準の許可プロンプトを提示し、拒否・タイムアウト時はデフォルト地点（東京等）へ静かにフォールバックさせます。

