# TestFlight 配信手順と運用ガイド (atmo)

本ノートは、気圧監視・気象病対策ツール（`atmo-app`）を有料の Apple Developer Program を用いて TestFlight へ配信し、実機検証および外部テストを行うための手順と設計を記録したものである。

---

## 1. TestFlight 配信の全体概要

Apple Developer Program への登録により、従来の Personal Team による「7日ごとの USB 転送制限」が解消され、クラウド経由で最大 90 日間有効なベータ版アプリを配信可能となる。

TestFlight には以下の2種類のテスト形式が存在する。

| テスト種別 | 対象者 | Apple 審査 | 反映速度 | 主な用途 |
|---|---|---|---|---|
| **内部テスト (Internal Testing)** | Developer アカウントのメンバー（最大100人） | **不要**（審査なし） | アップロード処理完了後、即時配信 | 開発者本人・チーム内の動作検証 |
| **外部テスト (External Testing)** | メールアドレス招待、または公開リンク（最大10,000人） | **必要**（ベータ版審査、通常24h以内） | 審査通過後に配信開始 | 先行テスターへの配布、フィードバック収集 |

まずは審査不要で即座にインストール可能な **内部テスト** の開通を目指す。

---

## 2. 事前準備 (Apple Developer Portal / App Store Connect)

### 2.1. App ID の登録
1. [Apple Developer Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) にアクセス。
2. 「Identifiers」の「＋」ボタンをクリックし、「App IDs」を選択して「Continue」。
3. タイプとして「App」を選択。
4. 以下の情報を入力:
   - **Description**: `atmo`
   - **Bundle ID**: `Explicit` を選択し、`net.aooba.atmoApp` を入力。
5. **Capabilities** リストから **「App Groups」** にチェックを入れる。
6. 「Continue」をクリックし、「Register」を完了する。

### 2.2. App Group の登録と紐付け
`atmo` はウィジェットとメインアプリ間でデータを共有するために App Groups を使用している。

1. 再度「Identifiers」の「＋」をクリックし、右上のドロップダウンから **「App Groups」** を選択して「Continue」。
2. 以下の情報を入力:
   - **Description**: `atmo App Group`
   - **Identifier**: `group.net.aooba.atmo`
3. 「Register」を完了する。
4. 先ほど作成した App ID（`net.aooba.atmoApp`）をリストから開き、Capabilities の「App Groups」横の「Configure」または「Edit」をクリック。
5. 作成した `group.net.aooba.atmo` にチェックを入れて保存（Save）する。

### 2.3. App Store Connect での新規 App 作成
1. [App Store Connect](https://appstoreconnect.apple.com/) にサインイン。
2. 「マイ App」を開き、「＋」ボタンから「新規 App」を選択。
3. 以下の項目を設定:
   - **プラットフォーム**: `iOS` にチェック
   - **名前**: `atmo`（重複する場合は `atmo - 気圧アラート` 等）
   - **主要言語**: `日本語`
   - **バンドルID**: プルダウンから `net.aooba.atmoApp` を選択
   - **SKU**: 一意の英数字（例: `atmo-ios-001`）
   - **ユーザアクセス**: `完全アクセス`
4. 「作成」をクリック。

---

## 3. クライアントプロジェクトの設定 (Xcode / Flutter)

### 3.1. 輸出コンプライアンス宣言の自動化 (`Info.plist`)
TestFlight にビルドをアップロードするたびに「輸出コンプライアンス情報がありません」というダイアログが表示されるのを防ぐため、`ios/Runner/Info.plist` に以下を追加する。

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### 3.2. Xcode での署名とチーム設定
1. Xcode でプロジェクトを開く:
   ```bash
   cd /Users/aobaiwaki/atmo-app
   open ios/Runner.xcworkspace
   ```
2. 左側ナビゲーターで最上部の「Runner」プロジェクトを選択。
3. ターゲット「Runner」を選択し、「Signing & Capabilities」タブを開く。
4. **Team** に有料 Apple Developer アカウント（組織または個人名）を選択。
5. **Automatically manage signing** が有効になっていることを確認。
6. Capabilities に「App Groups」が表示されていることを確認し、`group.net.aooba.atmo` にチェックが入っている状態にする（未追加の場合は「+ Capability」から追加）。

### 3.3. バージョンとビルド番号の管理
アップロードごとに、ビルド番号（Build Number）を増分する必要がある。`pubspec.yaml` の `version` フィールドで管理する。

```yaml
version: 1.0.0+1  # 次回アップロード時は +2, +3 とインクリメント
```

---

## 4. ビルドと TestFlight へのアップロード

### 4.1. Flutter による IPA ビルド
ターミナルから以下のコマンドを実行して、リリース用アーカイブおよび IPA ファイルを生成する。

```bash
cd /Users/aobaiwaki/atmo-app
flutter clean
flutter pub get
flutter build ipa --release
```

ビルドが完了すると、`build/ios/ipa/atmo_app.ipa` が生成される。

### 4.2. App Store Connect へのアップロード

アップロードには主に以下の2つの手段がある。

#### 方法 A: Transporter アプリを使用（推奨・最も簡便）
1. Mac App Store から無料の [Transporter](https://apps.apple.com/jp/app/transporter/id1450874784) をインストール。
2. Apple ID でサインイン。
3. 生成された `build/ios/ipa/atmo_app.ipa` を Transporter にドラッグ＆ドロップ。
4. 「配信」ボタンをクリックしてアップロード完了を待つ。

#### 方法 B: Xcode Organizer を使用
1. Xcode メニューの「Product」>「Archive」を実行。
2. オーガナイザー（Organizer）が開いたら、対象ビルドを選択して「Distribute App」をクリック。
3. 「App Store Connect」>「Upload」を選択し、画面の指示に従ってアップロード。

---

## 5. TestFlight での実機テスト手順

### 5.1. ビルドの処理待ち
アップロード完了後、[App Store Connect](https://appstoreconnect.apple.com/) の「マイ App」>「atmo」>「TestFlight」タブを開く。
- 初回アップロード時は、ステータスが「処理中（Processing）」と表示される（通常 5〜15分程度で完了）。
- 処理が完了すると「テスト準備完了」に切り替わる。

### 5.2. 内部テストグループへの追加
1. TestFlight タブ左メニューの「内部テスト」横にある「＋」をクリックし、グループ名（例: `Core Developers`）を作成。
2. 「テスター」欄で「＋」をクリックし、自分の Apple ID（メールアドレス）を選択して追加。
3. ビルド欄で、処理が完了した最新ビルドをグループに関連付ける。

### 5.3. iPhone 実機でのインストール
1. iPhone で App Store を開き、無料の「TestFlight」公式アプリをインストール。
2. Developer アカウントと同じ Apple ID でサインインしている場合、TestFlight アプリを起動すると自動的に「atmo」が表示される。
   （または招待メール内の「View in TestFlight」リンクを開く）
3. 「インストール」をタップ。

---

## 6. トラブルシューティング

| 症状 | 主な原因 | 対処法 |
|---|---|---|
| **App ID 登録時に重複エラー** | 既に他者が同じ Bundle ID を使用している | ユニークなドメイン（例: `net.aooba.atmoApp` や独自サブドメイン）に変更。 |
| **アップロード時に「Missing Compliance」** | 輸出暗号化の宣言が不足 | `Info.plist` に `ITSAppUsesNonExemptEncryption = false` を設定して再ビルド。 |
| **App Group が認識されない** | Developer Portal の App ID 設定で App Group が有効化されていない、またはプロファイル不整合 | Developer Portal で App Groups を再確認し、Xcode で署名を再同期。 |
| **バージョン番号重複エラー** | 前回のアップロードと同じビルド番号で再アップロードした | `pubspec.yaml` のビルド番号（`+1` -> `+2`）を増やして再ビルド。 |

---

## 7. 公式ドキュメント・一次情報源

- [Apple Developer: TestFlight Overview](https://developer.apple.com/testflight/) - TestFlight 概要
- [Apple Developer: Distribute an app using TestFlight](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases) - Xcode からのベータ配信手順
- [Apple Developer: App Groups Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups) - App Groups 仕様
- [Flutter Documentation: Build and release an iOS app](https://docs.flutter.dev/deployment/ios) - Flutter iOS リリース公式ガイド
