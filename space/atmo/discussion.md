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
| **Phase 3** | **Web版実用テスト** | Cloudflare Pages / k8s Ingress へのWebビルドデプロイと日常運用 | **進行中** |
| **Phase 4** | **iOS実機アプリ化** | Xcode Free Provisioning（無料Apple ID）によるiPhone実機転送 | 未着手 |
| **Phase 5** | **ウィジェット・通知** | ロック画面/ホーム画面ウィジェット、急変時のローカル通知 | 未着手 |

---

## 決定事項 (ADR一覧)

- **ADR-001**: グラフ可視化に `fl_chart` を採用（動的ベジェ曲線＋ツールチップ）。
- **ADR-002**: カードUIはサードパーティUIキット（GetWidget等）を排除し、**Flutter標準機能（外部依存ゼロ）** でグラデーション・枠線・気圧スケールバーを構築。
- **ADR-003**: データモデルは Dart 3 の `extension type` を活用し、ボイラープレートを50%以上削減。

---

## 関連ドキュメント・リポジトリ

- [note/01_ui_component_evaluation_and_architecture.md](note/01_ui_component_evaluation_and_architecture.md) - UIコンポーネント詳細評価レポート
- [AobaIwaki123/atmo (GitHub)](https://github.com/AobaIwaki123/atmo) - Go バックエンド
- [AobaIwaki123/atmo-app (GitHub)](https://github.com/AobaIwaki123/atmo-app) - Flutter フロントエンド
