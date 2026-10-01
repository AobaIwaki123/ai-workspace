# 0002. 単一責務 PR (Single Responsibility PR) 原則と CI 体系化の採用

## ステータス
承認済み (Accepted) - 2026-08-22

## コンテキスト
開発速度が向上するにつれ、複数の変更（Go コード修正、スクリプト改修、CI ワークフロー変更、ドキュメント更新）が単一の PR に混ざり、以下の問題が生じた：
1. レビューコストの増大と、変更内容の追跡困難。
2. ドキュメント修正やスクリプト修正のたびに無関係な Go のテスト・リントが走り、CI リソースの浪費とフィードバック遅延が発生。
3. シェルスクリプトやワークフロー内でのサイレントなエラー握りつぶし（`|| true` や `2>/dev/null`）の見落とし。

## 決定事項

### 1. 単一責務 PR 原則の厳格化
- **1 PR = 1 つの責務（ファイル群）** に厳格に分離する。
- 異なる関心事の変更は別ブランチ・別 PR として起票し、依存関係がある場合は Stacked PR 形式で管理する。

### 2. CI ワークフローの体系化・Path Filter 分離 (`ci-*`)
変更対象に応じて、独立した単一責務の CI ワークフローに分割する：
- **`CI - Go` (`.github/workflows/ci-go.yml`)**: `**.go`, `go.mod`, `api/**` 対象。`nilerr`, `errorlint`, `errcheck` による静的解析およびユニット/統合テスト。
- **`CI - Shell Scripts` (`.github/workflows/ci-scripts.yml`)**: `scripts/**` 対象。`shellcheck` によるシェルスクリプト静的解析。
- **`CI - Workflows` (`.github/workflows/ci-workflows.yml`)**: `.github/workflows/**` 対象。`actionlint` による GitHub Actions ワークフロー静的解析。

### 3. エラー握りつぶしの排除
- シェルスクリプト内での安易な `|| true` や `2>/dev/null` を禁止し、明示的なエラーハンドリングを徹底する。

## 効果・メリット
- **CI 実行時間の劇的短縮**: ドキュメントやスクリプトの修正時に Go CI がスキップされ、不要なリソース消費を完全排除。
- **サイレント障害の早期撲滅**: `nilerr`, `shellcheck`, `actionlint` の三重防御により、エラー隠蔽やスクリプト失敗をマージ前に 100% 検知。
