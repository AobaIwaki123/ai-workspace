# TicketDive API & URL Parser ディスカッション & 進捗管理 (discussion.md)

このドキュメントでは、TicketDive（チケットダイブ）のイベントURL解析、メタデータ抽出、および専用APIサーバー・ツール **`lumidive`**（`github.com/AobaIwaki123/lumidive`）の開発進捗を記録・管理します。

---

## 🎯 目的・ゴール

1. **イベントURL/短縮URLの高精度解析**:
   - `https://ticketdive.com/event/<id>`, `https://t-dv.com/<id>`, `https://ticketdive.com/event/fc/<id>`, またはイベントID（例: `plkt1022`）を受け付け、正規化する。
2. **完全な構造化データの抽出**:
   - Next.js SSRの `__NEXT_DATA__`（`props.pageProps.__superjsonProps.json`）およびNext.js Data JSONエンドポイントから、公演名、詳細、開場/開演日時、会場情報、出演者一覧、販売枠、各券種（価格、手数料、在庫/売り切れ状況、整理番号接頭辞）、アンケート設問、フライヤー画像を抽出する。
3. **`lumitree` スタイルの専用プロダクト `lumidive` の立ち上げ**:
   - Go 1.23+ 製の単一バイナリ、OpenAPI 3.0 仕様準拠、CLI/REST API/iCalendar (.ics) 生成機能、厳格なCI/CD基盤を具備した独立OSSとして公開する。

---

## 🗺️ ロードマップ / タスク

| Step | 項目 | 内容 | 状況 |
|:---|:---|:---|:---|
| **Step 1** | **URL解析・SSRデータ調査** | URL体系（`t-dv.com`短縮URL含む）、SSR内部JSON（`__NEXT_DATA__`）構造の解析 | ✅ 完了 ([note/01_url_analysis_and_internal_data.md](file:///Users/aobaiwaki/ai-workspace/space/ticketdive/note/01_url_analysis_and_internal_data.md)) |
| **Step 2** | **GitHub既存実装の網羅的調査** | GitHub上の既存TicketDive関連リポジトリの検索・フォーク適格性評価 | ✅ 完了 (API Serverの既存実装は存在せず) |
| **Step 3** | **プロトタイプ実装** | 外部依存なし（標準ライブラリのみ）で動作するURL解析スクリプトおよびHTTPサーバー | ✅ 完了 ([scripts/parse_ticketdive.py](file:///Users/aobaiwaki/ai-workspace/space/ticketdive/scripts/parse_ticketdive.py), [scripts/server.py](file:///Users/aobaiwaki/ai-workspace/space/ticketdive/scripts/server.py)) |
| **Step 4** | **独立リポジトリ `lumidive` の作成** | GitHub上に `AobaIwaki123/lumidive` を作成しローカル（`/Users/aobaiwaki/lumidive`）へクローン | ✅ 完了 ([github.com/AobaIwaki123/lumidive](https://github.com/AobaIwaki123/lumidive)) |
| **Step 5** | **初期スキャフォールド PR #1 の起票・拡張・マージ** | OpenAPI 3.0 仕様（メタデータ・統計集計・バッチ・キャッシュ制御の拡張性を強化）、クライアント、パーサー、キャッシュ、APIサーバー、CLI、単体テスト、CI/CDワークフロー | ✅ PR #1 マージ完了 (CI 100% PASS) |
| **Step 6** | **本番運用・デプロイ基盤整備** | Kubernetes マニフェスト（ArgoCD連携）、コンテナイメージ公開（ghcr.io） | 進行可能 |

---

## 📝 決定事項 (ADR一覧)

- [**`note/01_url_analysis_and_internal_data.md`**: URL解析・内部データ構造および既存OSS調査ノート](file:///Users/aobaiwaki/ai-workspace/space/ticketdive/note/01_url_analysis_and_internal_data.md)

---

## 📌 直近のネクストアクション

- [x] 指定URL `https://ticketdive.com/event/plkt1022` のデータ解析と抽出検証
- [x] 新規リポジトリ `AobaIwaki123/lumidive` の作成および初期実装
- [x] OpenAPI 3.0 仕様の拡張性強化（`metadata`, `stats`, `SourceMetadata`, `POST /api/v1/events/batch`, `refresh` パラメータ）
- [x] 不要な外部依存（`kin-openapi` / yaml / jsonパースライブラリ群）の完全排除
- [x] `lumidive` PR #1 起票・マージ完了（`main` ブランチの CI `ci-go.yml` も 100% PASS 確認済み）
- [ ] 必要に応じた Kubernetes マニフェスト整備と自宅クラスタ（ArgoCD）へのデプロイ検討
