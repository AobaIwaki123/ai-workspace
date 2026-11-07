# App Store 審査差し戻し対応メモ（Guideline 2.1 - Information Needed）

2026年11月3日に App Store Connect（Apple Review）より受領した、iOSアプリ「ソラケア」バージョン 1.0 に対する審査追加情報要求（Guideline 2.1）の要約、分析、および対応手順。

---

## 1. 受信通知の概要と現状ステータス

| 項目 | 内容 |
|---|---|
| アプリ名 | ソラケア (SoraCare) |
| プラットフォーム / バージョン | iOS / 1.0 |
| Submission ID | `cbd294f8-4709-4c95-984d-6fe23c1f9455` |
| 受信日時 | 2026年11月3日 06:40 JST (2026-11-02 04:01 PST 提出分) |
| 対象ガイドライン | [Guideline 2.1 - Performance: App Completeness (Information Needed)](https://developer.apple.com/app-store/review/guidelines/#app-completeness) |
| 現在の状況 | **審査一時保留（Information Needed）** |

### 性格と位置づけ
本通知はアプリの致命的な規約違反による拒絶（Reject）ではなく、**新規アプリ審査（New App Submission）において審査員がアプリの全貌・動作確認・外部連携・アカウント管理を把握するために追加情報提供を求める手続き**です。

指示された情報を App Store Connect の「App Review に関する情報（App Review Information）」内の「メモ（Notes）」および添付ファイルで提出し、再提出（Resubmit）することで審査が再開されます。

---

## 2. Apple Review が要求している 6 つの項目

Apple Review から提示された「Next Steps」の要求事項と、それぞれの確認ポイントは以下の通りです。

### (1) 実機での画面収録動画 (Screen Recording on a Physical Device)
- **要件**:
  - 最新の iOS が動作する物理デバイス（実機端末）で録画されていること。
  - アプリの起動（Launch）から始まり、典型的なユーザーフロー（主要機能の一連の操作）を網羅すること。
- **アプリに該当機能がある場合の必須収録項目**:
  - **アカウント登録・ログイン・アカウント削除**:
    - アカウント作成機能を持つアプリは、アプリ内から直接アカウントを削除できる導線が必須（[App Store Review Guideline 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)）。この削除フローも動画内で実演する必要があります。
  - **ユーザー生成コンテンツ (UGC)**:
    - ユーザー間の投稿・コメントがある場合、通報（Report）およびブロック（Block）の機構が実機上で動作している様子。
  - **課金コンテンツ (In-App Purchase)**:
    - 有料機能やサブスクリプションへのアクセス導線。

### (2) アプリの目的とターゲット層 (Purpose & Target Audience)
- アプリが解決する具体的な課題（Problem）。
- 想定利用者（Target Audience）と提供価値（Value）。

### (3) 主要機能のセットアップ・アクセス手順 (Setup & Access Instructions)
- レビュー担当者がアプリの全機能を試すための操作手順。
- ログインが必要な場合は、**動作確認済みのデモ用アカウント（ID・パスワード）**。
- 初期データが必要な場合のサンプルデータの登録状況や投入方法。

### (4) 外部サービス・外部プラットフォームの一覧 (External Services & Platforms)
- アプリのコア機能を提供するために連携している外部サービスの一覧。
  - 例: 気象データプロバイダー、認証プロバイダー（Firebase, Apple Sign-in 等）、決済プロセッサ、AI サービス、外部 API サーバー等。

### (5) 地域差（リージョンによる機能・コンテンツ差異）の有無 (Regional Differences)
- 日本国内専用の機能・コンテンツがあるか、あるいは全世界で一貫して動作するか。
- 日本国外の Apple レビュー担当者がアクセスした場合でも正常に動作するか（IP 制限や地域判定による制限がないかの確認）。

### (6) 規制対象業界・第三者保護コンテンツの証明 (Regulated Industry / Protected Material)
- ヘルスケア、医療、気象警報、金融などの規制分野に該当するかどうか。
- 第三者の商標・データ・コンテンツを利用している場合、正当な利用権限（ライセンス、提携契約、API 利用許諾）を有していることの証明・説明。

---

## 3. 対応手順（アクションプラン）

```
[1. 実機操作の画面録画]
  - 最新 iOS 実機でアプリ起動〜主要機能利用の一連の操作を画面収録
  - (該当する場合) ログイン、ログアウト、アカウント削除導線を含める
       ↓
[2. 回答文（Notes）の作成]
  - 英語（推奨）または日本語で 6 つの質問に対する回答を整理
       ↓
[3. App Store Connect での入力・添付]
  - アプリ > バージョン 1.0 > 「App Review に関する情報」
  - 「メモ (Notes)」欄に回答テキストを入力
  - 「添付ファイル (Attachment)」に録画動画をアップロード（またはリンク記載）
       ↓
[4. 再提出 (Resubmit for Review)]
```

---

## 4. App Store Connect「メモ (Notes)」回答テンプレート案

App Store Connect の審査員は英語ネイティブまたは英語ベースでレビューを行うケースが多いため、**英語での回答（必要に応じて日本語併記）** がスムーズです。

```text
Dear App Review Team,

Thank you for your review. Below is the requested information for "ソラケア" (Version 1.0, Submission ID: cbd294f8-4709-4c95-984d-6fe23c1f9455).

1. Screen Recording:
We have attached a physical device screen recording demonstrating the typical user flow from launch to core features.
(Note: If the video exceeds the attachment size limit, provide a secure streaming/download link here: [Link])

2. App Purpose & Target Audience:
- Purpose: [アプリの目的を記載、例: ソラケア is designed to help users track weather changes and manage physical conditions accordingly...]
- Target Audience: [ターゲット層、例: Individuals sensitive to weather/atmospheric pressure changes...]
- Problem Solved & Value: [提供価値を記載]

3. Setup & Access Instructions:
- [ログイン不要の場合] No login is required to use the core functionality of this app.
- [デモアカウントが必要な場合]
  - Demo Account Username/Email: demo@example.com
  - Demo Account Password: [Password]
- Steps to access main features:
  1. Launch the app.
  2. ...

4. External Services & Platforms:
- Weather Data Provider: [例: Open-Meteo API / Japan Meteorological Agency public data]
- Backend / Cloud Infrastructure: [例: Cloudflare / AWS / Supabase]
- Analytics / Crash Reporting: [例: None / TelemetryDeck]

5. Regional Differences:
The app functions consistently across all regions without region-specific restrictions. (または: Core weather data focuses on Japan, but the app is accessible and fully functional globally.)

6. Regulated Industry & Third-Party Material:
- The app does not provide medical diagnoses or medical advice; it is a general wellness/lifestyle tracking tool.
- All weather data and assets used in the app are licensed or utilized in accordance with public API terms of service.

Please let us know if any further details are required.

Best regards,
Aoba Iwaki
```

---

## 5. 公式リファレンスリンク

- [Apple Developer - App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Developer - Guideline 2.1: Performance - App Completeness](https://developer.apple.com/app-store/review/guidelines/#app-completeness)
- [Apple Developer - Guideline 5.1.1: Data Collection and Storage (Account Deletion Requirement)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [Apple Developer - App Review Information (App Store Connect Help)](https://developer.apple.com/help/app-store-connect/manage-app-status/view-app-review-status/)
