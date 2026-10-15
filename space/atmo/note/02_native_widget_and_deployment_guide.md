# ホーム画面ウィジェット実装とネイティブ配信・実機転送手順書 (atmo)

本ノートは、気圧監視・気象病対策ツール（`atmo-app`）におけるホーム画面ウィジェットの実装設計、Android 向け野良 APK 自動配信パイプライン、および iPhone への無料実機転送（Personal Team / 開発者モード）の手順と技術的知見を記録したものである。

---

## 1. 概要と背景

気圧急変に伴う頭痛や自律神経失調を未然に察知するにあたり、アプリを毎回能動的に開く運用は認知負荷が高い。ホーム画面を一瞥するだけで過去・未来の気圧推移と現在地の状況が把握できる「ホーム画面ウィジェット」こそが、本ツールのコアバリューである。

商用ストア（App Store / Google Play）の審査や開発者登録費用（Apple Developer Program 年間 $99 等）の課金を先送りし、手元で高速に実用検証を行うため、以下のハイブリッド配信戦略を採用した。

| プラットフォーム | 配信・検証方針 | 費用 | 特徴・制限 |
|---|---|---|---|
| **Android** | GitHub Actions による野良 APK 自動ビルド & GitHub Releases 配布 | 無料 | ストア審査なし。ブラウザから直接ダウンロード・即時インストール可能。 |
| **iOS (iPhone)** | Xcode Personal Team（無料 Apple ID）を用いた USB 実機転送 | 無料 | 年間 $99 の課金不要。開発者モードで転送。無料証明書のため 7 日ごとに再転送が必要。 |

---

## 2. ウィジェットのアーキテクチャ設計

### オフスクリーンレンダリング方式 (`home_widget`)
Flutter でグラフ主役のウィジェットをネイティブ（iOS / Android）双方に提供するため、**`home_widget` によるオフスクリーン画像レンダリング方式** を採用した。

```text
[ Flutter (Dart) ]
  │
  ├─ 1. 気圧API・位置情報取得 (Nominatim 逆引き含む)
  ├─ 2. AtmoSmallWidgetView / AtmoMediumWidgetView (CustomPainter ベジェ曲線)
  ├─ 3. HomeWidget.renderFlutterWidget() -> PNG画像を共有ストレージへ保存
  └─ 4. HomeWidget.updateWidget() -> ネイティブOSへ更新通知
         │
         ├───────────────────────────────┐
         ▼                               ▼
[ iOS WidgetKit (SwiftUI) ]    [ Android AppWidget (Kotlin) ]
  ├─ App Group 共有ストレージ      ├─ SharedPreferences / 内部ストレージ
  ├─ UIImage(contentsOfFile:)     ├─ BitmapFactory.decodeFile()
  └─ 158x158 / 338x158 表示       └─ RemoteViews (ImageView) 表示
```

### なぜネイティブ描画（SwiftUI Charts / Android Canvas）を避けたか
1. **完全なビジュアル同期 (Pixel-Perfect)**:
   - Flutter 側で緻密に調整したベジェ曲線スパークライン、現在時刻のドット、状態連動色、余白比率が、iOS / Android で寸分違わず同一に描画される。
2. **コードの二重保守の排除**:
   - SwiftUI と Android XML/Canvas で同一のグラフ描画ロジックを個別実装・デバッグする工数を全廃した。
3. **Web版プレビューとの完全一致**:
   - Web 版アプリ内の「ウィジェットプレビュー」で確認したグラフィックが、そのまま実機のホーム画面に現れる。

### 表示仕様
- **正時フォーマット (`HH:00`)**: バックグラウンド更新の性質を考慮し、分単位のブレを排して `14:00` のように視認性を最大化。
- **市区町村名表示**: Go バックエンドの空間グリッドキャッシュ（Nominatim 連携）により、緯度経度から「渋谷区」「千代田区」などの自治体名を自動表示。
- **2種類のサイズ**:
  - **Small (158×158)**: 地名 + 正時 + 状態インジケーター + 現在気圧 + ベジェ曲線スパークライン。
  - **Medium (338×158)**: 左側に現在気圧・3h変動、右側にワイドな24時間気圧推移グラフを展開。

---

## 3. Android: 野良 APK のダウンロード・インストール手順

Android 端末では、ストアを通さず GitHub Releases から直接 APK をダウンロードして利用できる。

### 1. APK のダウンロード
1. Android 端末のブラウザ（Chrome 等）で以下のリリースページを開く。
   - [atmo-app Releases (GitHub)](https://github.com/AobaIwaki123/atmo-app/releases)
2. 最新リリースの Assets から `app-release.apk` をタップしてダウンロードする。

### 2. インストール
1. ダウンロード完了通知またはファイルマネージャーから `app-release.apk` を開く。
2. 「セキュリティ上の理由から、この提供元からの不明なアプリをインストールすることはできません」と表示された場合は、**「設定」をタップして「この提供元のアプリを許可」をオン** にする。
3. 「インストール」をタップして完了を待つ。

### 3. 初期セットアップとウィジェット配置
1. インストールされた `atmo` アプリを起動する。
2. 位置情報の利用許可ダイアログで「アプリの使用時のみ許可」を選択する（現在地の市区町村名と気圧が読み込まれる）。
3. アプリを閉じ、端末のホーム画面の空きスペースを長押しする。
4. メニューから「ウィジェット」を選択し、一覧から「atmo」を探す。
5. 「Small（正方形）」または「Medium（横長）」を長押ししてホーム画面の好きな位置に配置する。

---

## 4. iPhone: 無料実機転送手順 (Personal Team)

Apple Developer Program（年間 $99）に加入せず、個人の Apple ID（無料アカウント）を用いて iPhone 実機へ転送・インストールする手順である。

### 必要な前提環境
- macOS 端末
- iPhone 実機（iOS 16 以降を推奨）
- USB-C または Lightning ケーブル

### 手順 A: Mac に Xcode をセットアップ
1. **Xcode のインストール**:
   - Mac App Store から [Xcode](https://apps.apple.com/jp/app/xcode/id497799835) をインストールする（約 30〜50GB の空き容量が必要）。
2. **コマンドラインツールの切り替え**:
   - インストール完了後、Mac のターミナルで以下を実行してアクティブな開発環境を切り替える。
     ```bash
     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
     sudo xcodebuild -runFirstLaunch
     ```

### 手順 B: iPhone の「デベロッパモード」を有効化 (iOS 16+)
iOS 16 以降の実機に野良アプリ（手元ビルド）を転送するには、デベロッパモードの有効化が必須である。
1. iPhone を Mac に USB 接続し、iPhone 画面で「このコンピュータを信頼しますか？」が出たら「信頼」をタップしてパスコードを入力。
2. iPhone の「設定」アプリを開く。
3. **「プライバシーとセキュリティ」** をタップ。
4. 一番下までスクロールし、**「デベロッパモード」** をタップ。
5. トグルを「オン」にする。
6. ダイアログに従い iPhone を再起動する。
7. 再起動後、ロック解除時に表示される確認ダイアログで「オンにする」をタップし、パスコードを入力。

### 手順 C: Xcode での無料署名設定 (Personal Team)
1. Mac のターミナルで `atmo-app` ディレクトリに移動し、Xcode ワークスペースを開く。
   ```bash
   cd ~/atmo-app
   open ios/Runner.xcworkspace
   ```
2. Xcode の左ナビゲーター最上部の青いアイコン **「Runner」** を選択。
3. 中央のタブで **「Signing & Capabilities」** を選択。
4. **Team** のドロップダウンをクリックし、「Add an Account...」から自分の Apple ID（無料アカウント）でサインイン。
5. サインイン後、Team に **`自分の名前 (Personal Team)`** を選択する。
6. Bundle Identifier が重複エラーになった場合は、`net.aooba.atmoApp` 等のユニークな文字列に適宜変更する。

### 手順 D: 実機転送と実行
1. Xcode ウィンドウ上部のデバイス選択メニューで、接続中の自分の iPhone を選択。
2. ターミナル、または Xcode の「Run（再生ボタン）」からビルド・転送を実行する。
   ```bash
   flutter run -d <iPhoneのデバイス名>
   ```
3. 初回起動時に iPhone 上で「信頼されていないデベロッパ」と表示された場合:
   - iPhone の「設定」>「一般」>「VPNとデバイス管理」を開く。
   - デベロッパ App 欄にある自分の Apple ID をタップし、「"自分のApple ID" を信頼」をタップする。

> [!NOTE]
> 無料の Apple ID（Personal Team）で署名したアプリは、**7 日間の有効期限** があります。期限が切れた場合は Mac に再接続して `flutter run` または Xcode から再転送することで更新できます。

---

## 5. バックグラウンド更新と運用設計

### 更新頻度
- **1時間間隔（Best Effort）**:
  - Android: `AppWidgetProvider` の `updatePeriodMillis` を 3,600,000ms（1時間）に設定。
  - iOS: WidgetKit の `TimelineProvider` において、`nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())` としてタイムラインを供給。
- **アプリ起動時連動**:
  - アプリ本体をフォアグラウンドで開いた際にも、最新の気圧レポートを取得すると同時にウィジェット画像が即時再生成・上書き更新される。

### OS の省電力制限に対する考慮
iOS / Android の最新 OS は、ウィジェットの過度なバックグラウンド更新をバッテリー保護のために制限する。
- 画面がオフの間や夜間は OS 判断で更新がスキップされる場合がある。
- 正確なリアルタイム気圧を直ちに確認したい場合は、ウィジェットをタップしてアプリ本体を起動することで、1秒以内に最新気圧・地名に同期される。

---

## 6. 関連ドキュメント・公式一次ソース

- [Apple Developer: WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit) - 公式 WidgetKit API 仕様
- [Apple Developer: Enabling Developer Mode on a device](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) - iOS デベロッパモードの有効化手順
- [Android Developers: App widgets overview](https://developer.android.com/develop/ui/views/appwidgets/overview) - Android ホーム画面ウィジェット開発ガイド
- [pub.dev: home_widget package](https://pub.dev/packages/home_widget) - Flutter home_widget プラグイン仕様
- [AobaIwaki123/atmo-app (GitHub)](https://github.com/AobaIwaki123/atmo-app) - Flutter クライアントリポジトリ
- [AobaIwaki123/atmo (GitHub)](https://github.com/AobaIwaki123/atmo) - Go バックエンドリポジトリ
