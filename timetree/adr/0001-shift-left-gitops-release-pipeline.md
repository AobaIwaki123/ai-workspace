# 0001. 保護ルールを維持した Shift-Left GitOps リリースパイプラインの採用

## ステータス
承認済み (Accepted) - 2026-08-22

## コンテキスト
`lumitree` では Kubernetes クラスタ（ArgoCD）による GitOps 運用を行うにあたり、以下の課題が存在した：
1. 本番ブランチ（`release`）は保護ルール（Protected Branch）が設定されており、直接の Push や Bot による強制書き換えはセキュリティ上禁止されている。
2. アプリケーションコードのリリースと、Kubernetes マニフェスト（`image: ...:vX.Y.Z`）の更新を分離せず、安全に自動同期する必要がある。
3. リリースタグ生成とマニフェスト更新が並行すると、Git の 3-way merge においてマニフェスト競合（Conflict）が発生する。

## 決定事項 (Pattern A: Shift-Left GitOps モデルの採用)
`origin/release` を起点とした Fast-Forward な一時ステージングブランチ（`release-stage/vX.Y.Z`）を介して、マージ前にマニフェスト更新とイメージ Push を完了させる **Shift-Left GitOps パイプライン** を採用する。

### ワークフローの構成
1. **Release PR の自動生成 (`release-pr.yml`)**:
   - `main` マージ時に、`git tag -l 'v*' | sort -V | tail -n 1` でリポジトリ全体の最大セマンティックバージョンを取得し、次期タグ（`vX.Y.Z`）を自動計算。
   - `origin/release` を起点に `release-stage/vX.Y.Z` を作成し、`main` の成果を取り込んだ上でマニフェストタグを更新。
   - `release-stage/vX.Y.Z` -> `release` の Release PR を自動起票（コンフリクト 0 件保証）。
2. **事前コンテナ Push (`docker-publish.yml`)**:
   - Release PR 作成・更新時に、該当バージョンタグのイメージを事前に GHCR へ Push。
3. **本番リリース & ArgoCD 同期 (`tag-on-release-merge.yml`)**:
   - Release PR マージ時に Git タグを発行し、GoReleaser でバイナリを配布。
   - ArgoCD が `release` ブランチの変更を検知し、即座に無停止ローリングアップデートを実施。

## 効果・メリット
- **保護ルールの完全維持**: 保護ブランチのセキュリティ設定を一切緩和せず、通常の PR レビュー・マージフローのみで安全にリリース可能。
- **コンフリクトの構造的撲滅**: ステージングブランチの共通祖先が `release` の HEAD になるため、GitOps マニフェストの競合が 100% 発生しない。
- **Zero-Lag デプロイ**: マージ前にコンテナイメージが GHCR に存在するため、ArgoCD の `ImagePullBackOff` やデプロイ遅延がゼロになる。
