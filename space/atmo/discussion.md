# 気圧監視・気象病対策ツール (atmo) ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、気圧監視・気象病対策ツール (atmo) に関する目的、ロードマップ、議論の経緯、進捗を記録・管理します。

---

## 目的・ゴール

- 急激な気圧変化（低気圧急襲・高気圧急上昇）に伴う頭痛や自律神経失調を未然に防ぐ。
- Go製バックエンド（`atmo`、Kubernetes公開）と Flutter製クロスプラットフォームUI（`atmo-app`）を連携。
- 「外部依存最小・堅牢・最高の手触り」を実現する個人用気圧ダッシュボードの構築。

---

## ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
| :--- | :--- | :--- | :--- |
| **Phase 0** | **バックエンド基盤** | Open-Meteo連携、Go製メモリキャッシュAPI、k8sデプロイ、Discord通知 | **完了** |
| **Phase 1** | **フロントエンド土台** | Flutter環境構築、Dart 3 extension typeモデル、APIクライアント、Makefile整備 | **完了** |
| **Phase 2** | **UIコンポーネント選定** | fl_chart、shadcn_ui、GetWidget、Skeletonizer、標準機能の比較評価 | **完了** |
| **Phase 3** | **Web版実用運用** | k8s Ingress / Cloudflare 経由で `https://atmo.aooba.net` へ本番デプロイ | **完了** |
| **Phase 4** | **iOS実機アプリ化** | WidgetKit Extension (SwiftUI) コード整備、Xcode Free Provisioning 実機転送手順書策定 | **完了** |
| **Phase 5** | **ホーム画面ウィジェット** | home_widget による Small/Medium ウィジェット実装、Android 野良 APK 自動ビルド CI 稼働 | **完了** |
| **Phase 6** | **TestFlight / App Store 配信** | 有料 Apple Developer Program 連携、App Group 登録、IPA ビルドと TestFlight 内部テスト | **進行中** |

---

## 決定事項 (ADR一覧)

- **ADR-001**: グラフ可視化に `fl_chart` を採用（動的ベジェ曲線＋ツールチップ）。
- **ADR-002**: カードUIはサードパーティUIキット（GetWidget等）を排除し、**Flutter標準機能（外部依存ゼロ）** でグラデーション・枠線・気圧スケールバーを構築。
- **ADR-003**: データモデルは Dart 3 の `extension type` を活用し、ボイラープレートを50%以上削減。
- **ADR-004**: ホーム画面ウィジェットは `home_widget` によるオフスクリーンレンダリング方式を採用し、Flutter の CustomPainter グラフを iOS / Android 双方にピクセルパーフェクトで同一共有。
- **ADR-005**: 当初は無料 Personal Team 実機転送を採用していたが、Apple Developer Program 加入に伴い、TestFlight によるワイヤレス配信・最大90日運用へ移行。

---

## 関連ドキュメント・リポジトリ

- [note/01_ui_component_evaluation_and_architecture.md](note/01_ui_component_evaluation_and_architecture.md) - UIコンポーネント詳細評価レポート
- [note/02_native_widget_and_deployment_guide.md](note/02_native_widget_and_deployment_guide.md) - ホーム画面ウィジェット実装とネイティブ配信・実機転送手順書
- [note/03_testflight_distribution_guide.md](note/03_testflight_distribution_guide.md) - TestFlight 配信手順と運用ガイド
- [AobaIwaki123/atmo (GitHub)](https://github.com/AobaIwaki123/atmo) - Go バックエンド
- [AobaIwaki123/atmo-app (GitHub)](https://github.com/AobaIwaki123/atmo-app) - Flutter フロントエンド

