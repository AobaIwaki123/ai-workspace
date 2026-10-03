# 画像の永久キャッシュ規約とアセット最適化パイプライン (12_immutable_image_caching_and_asset_pipeline.md)

本ドキュメントは、メンバー写真アセットの配信において、**CDN パージ運用を完全撤廃し、表示速度の極大化とデータ転送量の最小化を実現する「永久不変キャッシュ (Immutable Caching)」および画像変換パイプライン** の仕様書です。

---

## 1. 永久キャッシュ (RFC 8246 `immutable`) を採用する理由

従来の Web アプリケーションでは、メンバー名（例: `kousaka-marino.jpg`）を画像パスとして使い回していたため、以下の問題が起きていました。
1. **CDN / ブラウザキャッシュ事故**: 写真を変更しても古い画像が表示され続け、ユーザーに「シークレットウィンドウで開いてください」と案内せざるを得ない。
2. **無駄な 304 再検証リクエスト**: 毎回 `If-Modified-Since` 等のヘッダーでサーバーに問い合わせが発生し、レイテンシと通信リソースを浪費。
3. **CDN パージ運用の手動負荷**: 更新のたびに Cloudflare 等の管理画面でキャッシュクリアを行う必要があった。

### 解決策: RFC 8246 `Cache-Control: immutable`
ファイル名自体に不変のコンテンツ識別子（UUID v7）を埋め込むことで、**「URL が同一であれば中身は永久に変わらない」ことをブラウザと CDN に宣言** します。

---

## 2. 永久キャッシュの HTTP レスポンスヘッダー仕様

バックエンド（Go）が `/images/members/{imageKey}` を配信する際、以下のレスポンスヘッダーを厳格に付与します。

```http
HTTP/1.1 200 OK
Content-Type: image/webp
Cache-Control: public, max-age=31536000, immutable
ETag: "mem_019245a28c9d7a1e8f2b3c4d5e6f7a8b"
```

### ヘッダーの挙動
- `max-age=31536000` (1 年間): ブラウザおよび Cloudflare エッジに 1 年間完全キャッシュ。
- `immutable`: ユーザーがブラウザでページをリロード（F5 や引っ張って更新）しても、**ブラウザはサーバーに対して 304 再検証（Conditional GET）すら送信せず、端末内キャッシュから 0ms で画像をロード** します。

---

## 3. 写真更新ライフサイクル (Copy-on-Write / 不変ファイルモデル)

メンバーの公式写真やアー写が更新された場合、**既存のファイルを上書きすることは固く禁止** します。

```
[新写真アップロード]
       │
       ├── 1. 新しい UUID v7 を発行 (例: mem_01955b...)
       ├── 2. 画像をリサイズ・WebP 変換し、`mem_01955b....webp` として新規保存
       ├── 3. Member レコードの `ImageKey` カラムを新しいキーに更新
       │
[古い画像の処置 (Grace Period)]
       │
       └── 4. 古いファイル (`mem_019245....webp`) は即座に削除せず、
              30 日間の猶予期間（古いクライアントがアクセスする可能性を考慮）の後に非同期クリーンアップ
```

### メリット
- 画像を更新した瞬間から、全ユーザーに対して新ファイルが即時反映されます。
- CDN やブラウザのキャッシュパージは一切不要。キャッシュ不整合が原理的にゼロになります。

---

## 4. バックエンド画像変換パイプライン仕様

管理画面（`/admin`）から画像がアップロードされた際、バックエンド（Go）内で自動的に最適化処理を実行します。

| 項目 | 変換仕様 | 目的・根拠 |
|---|---|---|
| **出力フォーマット** | **WebP (`image/webp`)** | JPEG 比で約 30% 削減、全モダンブラウザでネイティブサポート |
| **最大サイズ** | **長辺 400px (アスペクト比維持)** | スマートフォンのクイズ画面・アバター表示に十分な解像度 |
| **品質 (Quality)** | **82%** | 人間の目では劣化が視認できず、ファイルサイズを **15〜25KB** に圧縮 |
| **EXIF 削除** | **完全除去 (Strip EXIF)** | 位置情報・撮影機材情報等のプライバシー保護と容量削減 |

---

## 5. 参考文献・公式仕様

- [RFC 8246 - HTTP Immutable Responses](https://www.rfc-editor.org/rfc/rfc8246.html)
- [MDN Web Docs: Cache-Control immutable](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control#immutable)
- [Google Developers: WebP Image Format Specification](https://developers.google.com/speed/webp)
