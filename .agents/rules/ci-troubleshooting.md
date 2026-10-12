# CI / Go / OpenAPI トラブルシューティング & ベストプラクティス (CI Troubleshooting Guide)

本ルールは、CI（GitHub Actions）の構築・実行、Go の依存関係管理、OpenAPI コード生成、静的解析（Linter）において過去に発生した失敗事例と、それを未然に防ぐための確立された対策・ノウハウをまとめた知見集です。

---

## 🚫 1. 絶対原則: 「ローカル完全検証」の徹底 (Pre-Push Verification)

- **失敗パターン**: 修正をとりあえず push して GitHub Actions で成否を確認する「Push 駆動デバッグ」を行い、大量の不要な CI 失敗コミットを量産してしまう。
- **解決策**:
  - 各リポジトリに `./scripts/verify-all.sh` を整備し、**コミット・Push 前に必ずローカルで全検証（コード生成・Linter・テスト -race・ビルド）を実行して 100% 成功することを確認する**。

---

## 2. `main` 反映を起点とする CI/CD の基本構成

コンテナ化されたサービスは、手元からレジストリや Kubernetes を直接操作せず、`main` に反映された変更を CI/CD の入力にする。PR-only 運用では、次の「main push」は原則として PR のマージによって発生する push を指す。

### 標準フロー

1. Pull Request で検証する。PR 用 CI は `go test`、linter、build、`./scripts/verify-all.sh` などの検証だけを行い、レジストリや本番環境を変更しない。
2. PR をレビューし、CI が Green になった後に `main` へマージする。
3. `main` への push を起点に GitHub Actions が次を実行する。
   - `GITHUB_TOKEN` と `packages: write` を使って GHCR にログインする。
   - `linux/amd64,linux/arm64` など必要な platform の image を build/push する。
   - `sha-${短縮コミットSHA}` のような変更不変の image tag を生成する。
   - Kubernetes manifest の image tag を更新し、必要なら GitHub Actions bot が変更を `main` に戻す。
4. Argo CD などの GitOps controller が manifest の変更を検知し、Kubernetes へ同期する。
5. rollout status、readiness、公開 endpoint、必要な実ログを確認する。

### 必須条件

- workflow の `permissions` に、ソース更新が必要な場合は `contents: write`、GHCR push が必要な場合は `packages: write` を明示する。
- image tag を更新する bot commit が同じ image workflow を再起動して無限ループにならないよう、`paths-ignore`、`[skip ci]`、または同等のガードを設ける。
- `latest` だけに依存せず、Kubernetes では commit SHA tag または digest を参照する。
- CI が担当する GHCR push のために、開発者のローカル PAT を要求しない。通常の反映で手動 `docker login`、`docker push`、`kubectl set image` を行わない。
- ローカルの未コミット変更は CI の入力にならない。未コミットのまま作った `*-dirty` image を本番反映に使わず、PR経由で `main` に反映して同じ検証をCI上でも実行する。
- CI 完了後に、Argo CD の同期状態、Deployment の実 image、Pod の readiness、公開 API の応答を確認する。UI/APIを持つサービスでは、生ログを確認できるコマンドを完了報告に含める。

### 最小構成例

```yaml
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  verify:
    # PR と main push の両方で実行する検証 job
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/verify-all.sh

  publish:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    permissions:
      contents: write
      packages: write
    steps:
      - checkout
      - build-and-push-image-with-github-token
      - update-kustomize-image-tag
      - commit-deployment-manifest-with-skip-ci
```

---

## 📦 3. Go バージョン不整合と推移的依存の要求 (`go >= 1.25` エラー)

- **失敗パターン**:
  - `golangci-lint` や `kin-openapi` などの依存が `requires go >= 1.25.0` や `the Go language version used to build golangci-lint is lower than targeted Go version` としてクラッシュする。
  - 原因: ローカルの最新 Go ツールチェーンが `go mod tidy` 時に勝手に `go.mod` のバージョンを `go 1.25.0` へ書き換えてしまう。
- **解決策**:
  - `go.mod` の `go` ディレクティブは常にプロジェクトのターゲットバージョン（例: `go 1.23.0`）に固定する。
  - Go 1.23 互換のバージョンを明示指定して依存を固定する:
    ```bash
    go get github.com/getkin/kin-openapi@v0.128.0 \
           github.com/oapi-codegen/runtime@v1.1.1 \
           github.com/oapi-codegen/oapi-codegen/v2@v2.4.1 \
           github.com/go-openapi/jsonpointer@v0.21.0 \
           golang.org/x/sync@v0.10.0 \
           golang.org/x/text@v0.21.0 \
           golang.org/x/tools@v0.28.0
    ```

---

## 📑 4. OpenAPI YAML の日本語コロンによる構文エラー

- **失敗パターン**:
  - `yaml: line XX: mapping values are not allowed in this context`
  - 原因: `description: 取得対象年（例: 2026）` のように、全角括弧内の半角コロン `:` を YAML パーサーが新たな key-value マッピングと誤認する。
- **解決策**:
  - YAML 内のすべての日本語説明文やコロン・特殊記号を含む文字列は、必ずダブルクォートで囲む:
    ```yaml
    description: "取得対象年（例: 2026）"
    ```
  - OpenAPI 作成・変更時は、即座に `oapi-codegen` や YAML バリデータで構文検証を行う。

---

## 🧹 5. `golangci-lint` (revive / errcheck) の必須対応

- **失敗パターン**:
  - `Error return value of w.Write is not checked (errcheck)`
  - `Error return value of resp.Body.Close is not checked (errcheck)`
  - `package-comments: should have a package comment (revive)`
  - `unused-parameter: parameter 'r' seems to be unused (revive)`
- **解決策**:
  1. **戻り値チェック**: `_, _ = w.Write(b)` や `defer func() { _ = resp.Body.Close() }()` で明示的に無視または処理。
  2. **パッケージコメント**: すべての `.go` ファイル先頭に `// Package <name> provides ...` を記述。
  3. **未使用引数**: 未使用の引数はアンダースコア `_ *http.Request` にリネーム。
  4. **生成コードの除外**: `.golangci.yml` の `issues.exclude-rules` で `.*\.gen\.go` を revive / errcheck の対象外に設定（`exclude-dirs` はコンテキストロードを壊す場合があるため `exclude-rules` を推奨）。

---

## 🔄 6. OpenAPI コード生成の Schema Drift 防止

- **失敗パターン**:
  - `openapi.yaml` を修正したのに Go コードを再生成し忘れ、実行時や API 配信時に不整合が発生する。
- **解決策**:
  - `pkg/api/doc.go` に `//go:generate` ディレクティブを配置し、`tools/tools.go` でツール依存を追跡。
  - CI のテストジョブで以下を実行してスキーマドリフトを完全検知:
    ```yaml
    - name: Verify Code Generation (Schema Drift Check)
      run: |
        go generate ./...
        git diff --exit-code
    ```
