# CI / Go / OpenAPI トラブルシューティング & ベストプラクティス (CI Troubleshooting Guide)

本ルールは、CI（GitHub Actions）の構築・実行、Go の依存関係管理、OpenAPI コード生成、静的解析（Linter）において過去に発生した失敗事例と、それを未然に防ぐための確立された対策・ノウハウをまとめた知見集です。

---

## 🚫 1. 絶対原則: 「ローカル完全検証」の徹底 (Pre-Push Verification)

- **失敗パターン**: 修正をとりあえず push して GitHub Actions で成否を確認する「Push 駆動デバッグ」を行い、大量の不要な CI 失敗コミットを量産してしまう。
- **解決策**:
  - 各リポジトリに `./scripts/verify-all.sh` を整備し、**コミット・Push 前に必ずローカルで全検証（コード生成・Linter・テスト -race・ビルド）を実行して 100% 成功することを確認する**。

---

## 📦 2. Go バージョン不整合と推移的依存の要求 (`go >= 1.25` エラー)

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

## 📑 3. OpenAPI YAML の日本語コロンによる構文エラー

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

## 🧹 4. `golangci-lint` (revive / errcheck) の必須対応

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

## 🔄 5. OpenAPI コード生成の Schema Drift 防止

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
