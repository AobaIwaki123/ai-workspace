# [App Store 審査対応] Guideline 2.1 (Information Needed) 実機 Widget 動作動画の収録 & Notes 提出

## 概要・背景
2026年11月3日に Apple Review より、iOS アプリ「ソラケア」（Version 1.0, Submission ID: `cbd294f8-4709-4c95-984d-6fe23c1f9455`）に対して **Guideline 2.1 (Information Needed)** の確認通知を受信しました。

本アプリは、気圧変化・頭痛リスクを素早く把握するための **「iOS Home Screen / Lock Screen Widget」** をコア価値として提供しています（アプリ本体は Flutter によるコンパニオン UI）。
審査員に対して **「実機での Widget 動作・遷移の画面収録動画」** を提示し、Notes 欄で Widget 中心であること、およびプライバシー設計（GPS不使用・アカウント不要）を明記して再提出を完了しました。

---

## 現在の進捗状況（現在地）

- [x] **Apple Review 通知の分析と要求項目の整理**（2026-11-07 完了）
- [x] **実機での画面収録動画の撮影・検証**（2026-11-07 完了）
  - ファイル: `/Users/aobaiwaki/Downloads/ScreenRecording_11-07-2026 10-19-29_1.MP4`
  - 変換後形式: `/Users/aobaiwaki/Downloads/soracare_demo_h264.mov` (18.4MB / 15.9秒 / H.264 MOV)
  - 内容: アプリ起動（1014.4hPa・48時間推移グラフ）＋ ホーム画面での **Small ウィジェットおよび Medium ウィジェットの両方がリアルタイム描画されている様子** を収録。
- [x] **App Store Connect「メモ (Notes)」用英文の作成および対訳の確認**（2026-11-07 完了）
- [x] **App Store Connect にて動画添付 ＆ Notes 貼り付け、バージョン 1.0 (Build 4) で再提出完了**（2026-11-07 完了）
- [ ] **【次回アクション】Apple Review による審査結果の受領待ち**（通常 24〜48 時間以内）

---

## 提出内容の控え（App Store Connect に提出済み）

### 1. 添付ファイル
- `soracare_demo_h264.mov`（実機画面収録動画）

### 2. メモ (Notes) 欄提出テキスト

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
