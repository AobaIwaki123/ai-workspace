# Zeitgeist (時代精神)

Go言語で実装された、マルチソース・トレンド＆メディアフェッチャーCLI。

複数メディア（RSS/Atom、HTMLスクレイピング、パブリックJSON等）から最新トレンド・話題のコンテンツを高速並行フェッチし、HTMLタグを除去・サニタイズしたクリーンな構造化JSONを標準出力（`stdout`）に出力します。

## 特徴

- **Adapter Pattern**: 媒体定義（Source）と取得実装（Driver）を分離。同一の取得方式（RSS等）を複数媒体で使い回し可能。
- **高速並行フェッチ**: Goroutineとセマフォにより、複数媒体を1秒未満で安全に並行取得。
- **耐障害性 (Graceful Degradation)**: 一部の媒体が404やタイムアウトで落ちても、CLI全体は停止せず取得できた媒体のみを返却。
- **AI / パイプライン親和性**:
  - `stdout`: クリーンなインデント付きJSON（各媒体の `description` メタデータを同梱し、AIが文脈を即時理解可能）。
  - `stderr`: `log/slog` による構造化ログ。
- **Config-Driven**: 取得対象の追加・変更はYAMLファイルの編集のみで完結。

## クイックスタート

```bash
# ビルド
go build -o zeitgeist ./cmd/zeitgeist

# サンプル設定で実行
./zeitgeist -config configs/sources.sample.yaml

# プライベート設定で実行（jqとパイプ連携）
./zeitgeist -config ../../private/data/zeitgeist/sources.yaml | jq .

# 特定カテゴリのみ絞り込み
./zeitgeist -config configs/sources.sample.yaml -category movie
```

## 検証

```bash
./scripts/verify-all.sh
```
