# 気圧監視ツール (atmo) フロントエンドUIライブラリ検証とアーキテクチャ選定

本ノートは、気象病・急激な気圧変化に伴う頭痛予防を目的とした気圧監視アプリ（`atmo-app`）における、FlutterフロントエンドのUIコンポーネントライブラリ評価実験、手触り検証結果、および技術的選定の知見を記録したものである。

---

## 1. 概要と背景

2026年10月14日、急激な気圧上昇（3時間で +3.5 hPa）による激しい頭痛と自律神経過緊張が発生したことを契機に、Go言語による気圧監視・キャッシュAPIサーバー（`atmo`、Kubernetes公開エンドポイント: `https://atmo.aooba.net`）を構築した。
本フェーズでは、このバックエンドから供給されるリアルタイム気圧JSONおよび時系列データを手元で素早く確認するためのクライアントアプリ（`atmo-app`、Flutter製）のUIデザインシステムの選定・評価を実施した。

---

## 2. 検証したコンポーネントライブラリ一覧

独立したPoCブランチを作成し、同一のAPIエンドポイントから実データを取得して、手触り、描画パフォーマンス、コードの簡潔さ、依存関係の重さを横並びで比較検証した。

| ライブラリ / 手法 | GitHub Stars / 参照元 | 検証内容 | 評価結果・手触り | 採否 |
|---|---|---|---|---|
| **fl_chart** | [imaNNeo/fl_chart](https://github.com/imaNNeo/fl_chart) (7.5k+ stars) | 48時間気圧推移の動的ベジェ曲線描画、グラデーション塗りつぶし、タップ時ツールチップ | 滑らかな曲線アニメーション、現在時刻のドット強調、ピンポイントの気圧数値ポップアップが極めて優秀。バックエンド生成の静的PNG画像と比較してアプリの完成度が劇的に向上。 | **採用** |
| **shadcn_ui** | [nank1ro/flutter-shadcn-ui](https://github.com/nank1ro/flutter-shadcn-ui) (1.5k+ stars) | Tailwind / Radix UIライクなモノトーンカード、バッジ、Lucideアイコン | 余白感、タイポグラフィ、繊細な境界線は高評価。しかしテーマシステムの独自色が強く、後述のFlutter標準機能で同等の質感が再現できたため依存削減で見送り。 | 参考保留 |
| **GetWidget** | [ionicfirebaseapp/getwidget](https://github.com/ionicfirebaseapp/getwidget) (4.8k+ stars) | `GFCard`, `GFBadge`, `GFListTile` による総合UIキット | アバターやバッジの装飾が野暮ったく、ミニマルなダークテーマの世界観に合致しなかった。「フォントは良いがそれ以外が微妙」と判断し却下。 | **却下** |
| **Skeletonizer** | [Milad-Akarie/skeletonizer](https://github.com/Milad-Akarie/skeletonizer) (1.8k+ stars) | 既存UIを包むだけの自動シマースケルトンローディング | 別途プレースホルダーUIを作らずに既存コードを流用できる点は神がかり的。ただしキャッシュAPIの応答が極めて高速なため、初期フェーズの依存最小化を優先して将来拡張枠へ。 | 将来拡張 |
| **Flutter標準機能** | [Flutter API Documentation](https://api.flutter.dev/) (SDK組込) | `Container` グラデーション、`Stack` / `LayoutBuilder` による自作気圧スケールバー | 微細な斜めグラデーション、状態連動ボーダー（シアン/レッド）、および現在気圧の位置を可視化するスケールバーを外部依存ゼロで構築。結果的にサードパーティ製を凌駕する洗練度を達成。 | **採用** |

---

## 3. 意思決定と選定理由 (ADR要約)

### 基本方針
「素朴な機能でどこまでいけるか評価し、差がなければ依存が最も軽いもの（外部依存最小）を採用する」。

### 採択理由
1. **外部依存の極小化**:
   - サードパーティ製のUIキットを導入すると、Flutterバージョンアップ時の破壊的変更やメンテナンス停止リスクを抱える。
   - 画面の骨格（カード・バッジ・スケールバー）を **外部依存ゼロ（Flutter標準機能のみ）** で組むことで、壊れない堅牢性と最高クラスの描画速度（60/120fps）を両立した。
2. **コアバリューへの投資**:
   - 「気圧の推移（48h）を滑らかな曲線で見る」というアプリのコア価値に対してのみ、デファクトスタンダードである **`fl_chart`** の単一外部パッケージを採用した。
3. **Dart 3 の最新機能活用**:
   - データモデル定義に Dart 3 の **`extension type`** を導入し、Java風の冗長なボイラープレート（フィールド宣言、コンストラクタ、`fromJson` の多重記述）を全廃。54行から22行へ半分以下に圧縮した。

---

## 4. 最終画面構成

```text
[ atmo-app 画面構成 ]
  │
  ├─ 1. アラートバナー (Flutter標準)
  │      └─ 急変検知時（isCaution: true）のみ赤系透過コンテナで表示
  │
  ├─ 2. 計器盤カード (Flutter標準)
  │      ├─ 背景: 微細な斜めダークグラデーション (Slate 800 -> Gray 900)
  │      ├─ 境界線: 状態連動の微細ボーダー (安定: Cyan / 警戒: Red)
  │      ├─ メイン数値: 特大気圧値 (1011.5 hPa) + トレンド矢印 (Icons.trending_up)
  │      └─ 気圧スケールバー: 990〜1030 hPa 内での現在位置を光るピンで表示
  │
  └─ 3. 48時間気圧推移チャート (fl_chart)
         └─ 滑らかな動的ベジェ曲線 + 下部透過グラデーション + タップ時ツールチップ
```

---

## 5. 一次情報・公式リファレンス

* [Flutter Official Documentation](https://docs.flutter.dev/) - Google Flutter公式
* [fl_chart (GitHub)](https://github.com/imaNNeo/fl_chart) - imaNNeo/fl_chart 公式リポジトリ
* [shadcn_ui on pub.dev](https://pub.dev/packages/shadcn_ui) - nank1ro/flutter-shadcn-ui
* [Skeletonizer on pub.dev](https://pub.dev/packages/skeletonizer) - Milad-Akarie/skeletonizer
* [atmo バックエンドリポジトリ (GitHub)](https://github.com/AobaIwaki123/atmo) - AobaIwaki123/atmo
* [atmo-app フロントエンドリポジトリ (GitHub)](https://github.com/AobaIwaki123/atmo-app) - AobaIwaki123/atmo-app
