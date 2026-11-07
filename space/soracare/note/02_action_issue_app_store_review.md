# [App Store 審査対応] Guideline 2.1 (Information Needed) 実機 Widget 動作動画の収録 & Notes 提出

## 概要・背景
2026年11月3日に Apple Review より、iOS アプリ「ソラケア」（Version 1.0, Submission ID: `cbd294f8-4709-4c95-984d-6fe23c1f9455`）に対して **Guideline 2.1 (Information Needed)** の確認通知を受信しました。

本アプリは、気圧変化・頭痛リスクを素早く把握するための **「iOS Home Screen / Lock Screen Widget」** をコア価値として提供しています（アプリ本体は Flutter によるコンパニオン UI）。
審査員に対して **「実機での Widget 動作・遷移の画面収録動画」** を提示し、Notes 欄で Widget 中心であること、およびプライバシー設計（GPS不使用・アカウント不要）を明記して審査を完了させます。

---

## 現在の進捗状況（現在地）

- [x] **Apple Review 通知の分析と要求項目の整理**（2026-11-07 完了）
- [x] **実機での画面収録動画の撮影・検証**（2026-11-07 完了）
  - ファイル: `/Users/aobaiwaki/Downloads/ScreenRecording_11-07-2026 10-19-29_1.MP4`
  - 尺: 15.9秒 / サイズ: 18.4MB / 解像度: 1170×2532 (iPhone実機ネイティブ、4G表示)
  - 内容: アプリ起動（1014.4hPa・48時間推移グラフ）＋ ホーム画面での **Small ウィジェットおよび Medium ウィジェットの両方がリアルタイム描画されている様子** を確認済み。
- [x] **App Store Connect「メモ (Notes)」用英文の作成および対訳の確認**（2026-11-07 完了）
- [ ] **【残作業】App Store Connect での動画アップロードと Notes 貼り付け・再提出**（後日実施）

---

## 【後日実施する残作業の手順】（所要時間: 約2分）

1. **[App Store Connect](https://appstoreconnect.apple.com/)** にアクセス
2. 「マイ App」 > 「ソラケア」 > 「1.0 審査中 / 提出準備中」を開く
3. 「App Review に関する情報 (App Review Information)」セクションへ移動
4. **「添付ファイル (Attachment)」** に動画ファイル（`ScreenRecording_11-07-2026 10-19-29_1.MP4`）をアップロード
5. **「メモ (Notes)」** 欄に、下記の **【コピペ用英文テキスト】** を貼り付け
6. 右上の **「審査に提出 (Resubmit for Review)」** ボタンをクリックして完了

---

## 【コピペ用】App Store Connect「メモ (Notes)」提出文

※以下のテキスト枠内をそのまま App Store Connect の「メモ (Notes)」欄に貼り付けて使用できます。

```text
Dear App Review Team,

Thank you for reviewing "ソラケア" (Version 1.0, Submission ID: cbd294f8-4709-4c95-984d-6fe23c1f9455). Below is the requested clarifying information.

1. Screen Recording (Physical Device):
We have attached a physical device screen recording demonstrating the typical user flow.
As shown in the video:
- The core functionality and primary value of "ソラケア" is its iOS Home Screen & Lock Screen Widgets, designed to allow users to glance at barometric pressure fluctuations and weather-headache risk indicators directly on their home screen without opening the app.
- The screen recording demonstrates:
  1. Launching the companion Flutter app from the Home Screen to view real-time pressure (1014.4 hPa) and the 48-hour barometric trend chart.
  2. Returning to the Home Screen to showcase both Small and Medium Widgets actively rendering real-time atmospheric pressure trends and caution badges.

2. App Purpose & Target Audience:
- Purpose: "ソラケア" (atmo) helps individuals manage weather-induced headaches and physical sensitivity by monitoring barometric pressure trends.
- Target Audience: People who experience weather-related headaches, migraines, or physical discomfort caused by sudden atmospheric pressure drops.
- Value: Instant, glanceable awareness on the Home Screen via Widgets, complemented by a lightweight 48-hour pressure chart in the app.

3. Setup & Access Instructions:
- No user registration, login, or account creation is required.
- All core features and Widgets are immediately accessible upon launch without any setup friction or credentials.

4. External Services & Platforms:
- Backend Cache API: A custom lightweight Go API server (`atmo`) providing in-memory cached pressure metrics.
- Weather Data Source: Open-Meteo Weather API (publicly licensed weather forecasting service) fetched hourly by the cache server.
- Privacy & Device Location: The app does NOT request or use iOS Location Services (GPS). Users manually select their preferred prefecture/city, ensuring complete user privacy.

5. Regional Differences:
The app and its Widgets function consistently across all regions. The weather data covers 47 prefectures in Japan and is accessible without regional geofencing.

6. Regulated Industry & Protected Material:
- The app is a personal wellness and lifestyle atmospheric pressure tracker. It does NOT provide medical diagnoses, treatment advice, or regulated health services.
- All weather data complies with Open-Meteo API terms, and all graphical chart assets are original.

Thank you for your time and guidance.

Best regards,
Aoba Iwaki
```

---

## メモ（Notes）記載内容の日本語対訳・解説

- **冒頭**: 審査への感謝と、要求された追加情報の提出である旨。
- **1. 実機での画面録画**: 実機録画を添付したこと。アプリの核心的価値は「開かずに気圧や頭痛リスクを素早く確認できる Widget」にあること。アプリ本体の起動（気圧1014.4hPa・48時間推移グラフ）およびホーム画面での Small/Medium ウィジェット両方のリアルタイム稼働を実演していること。
- **2. アプリの目的とターゲット**: 気圧低下による頭痛・偏頭痛・体調不良を抱えるユーザーの体調管理を支援すること。Widget による即座の確認とアプリ内の推移グラフによる補完を提供。
- **3. セットアップ・アクセス手順**: アカウント登録やログインは完全不要。インストール後セットアップ不要ですぐに全機能・ウィジェットが利用可能であること。
- **4. 外部サービス一覧**: Go 製キャッシュサーバー（`atmo`）および Open-Meteo API を利用。GPS 位置情報権限は一切使わず手動選択のみでプライバシーを保護していること。
- **5. 地域差の有無**: 日本の47都道府県をカバーしており、地域制限（ジオフェンシング）なく全世界で一貫して動作すること。
- **6. 規制業界・第三者コンテンツ**: 個人向けの生活・体調管理ツールであり、医療診断や治療アドバイス等の規制医療サービスには非該当であること。API 規約・著作権に準拠していること。
