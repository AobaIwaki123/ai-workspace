# ライブ会場での完全動作を保証する Local-First / オフライン PWA 設計 (11_local_first_offline_pwa_architecture.md)

本ドキュメントは、数万人規模のファンが集まる大型ライブ会場（東京ドーム、代々木第一体育館、さいたまスーパーアリーナ等の電波飽和・通信圏外エリア）において、**通信が途絶しても 100% クイズが動作し、回復時に自動同期する Local-First / PWA アーキテクチャ** の詳細設計です。

---

## 1. 解決すべき現場課題

アイドルライブの開演前 30〜60 分は、数万人規模のファンが同一セル内に密集し、キャリア回線（4G/5G）が極度の輻輳状態に陥ります。
旧システムでは、画面遷移やクイズ出題のたびに API リクエストを送信していたため、**ローディングスピナーが回り続けた末にタイムアウトエラーが発生し、開演直前の待機列で遊べない** という致命的弱点がありました。

---

## 2. Local-First 3層ストレージアーキテクチャ

本システムでは、サーバーへの常時通信前提を破棄し、**「データは手元（端末内）にあり、サーバーとは非同期で同期する」** Local-First モデルを採用します。

| ストレージ層 | 格納対象データ | キャッシュ戦略 | 保持期間 |
|---|---|---|---|
| **App Shell (CacheStorage)** | HTML, JS バンドル, CSS, アイコン | **Cache-First (PWA Service Worker)** | アプリバージョン更新まで永久 |
| **画像アセット (CacheStorage)** | メンバー写真 (`mem_<uuidv7>.webp`) | **Cache-First (不変キーによる永久保持)** | 最大 1 年（LRU で上限 50MB 管理） |
| **マスタデータ (IndexedDB)** | 全グループ、カラー、メンバー、期生情報 | **Stale-While-Revalidate (`/api/v1/sync/bootstrap`)** | 永続（バックグラウンドで差分更新） |
| **回答キュー (IndexedDB)** | 未送信の回答ログ (`ans_<uuidv7>`) | **Outbox パターン (FIFO キュー)** | サーバー同期完了まで保持 |

---

## 3. クライアント側純粋関数による「完全ローカル出題エンジン」

サーバーとの通信が完全に途絶（`navigator.onLine === false`）している場合でも、クイズ体験が 1 秒も止まらないよう、**クイズ設問生成エンジンをクライアント側（TypeScript）に完全移植可能な純粋関数（Pure Function）** として設計します。

```
[クライアント端末 (ブラウザ / PWA)]
  ├── 1. IndexedDB からアクティブメンバー一覧を取得
  ├── 2. 純粋関数 `generateQuizQuestion(members, strategy)` 実行
  │      └── 正解 1 名 + 類似色/ランダムダミー 3 名の選択肢を瞬時に算出
  ├── 3. 画面にクイズ描画 (レイテンシ 0ms、通信なし)
  ├── 4. ユーザー回答 ──► 即時正誤判定 & 解説表示
  └── 5. 回答結果を IndexedDB Outbox キューに保存
```

---

## 4. Background Sync による自動同期ライフサイクル

電波が途絶えている間にユーザーが解いた回答データは、通信が回復した瞬間に自動的にバックエンドへ同期されます。

```
[オフライン回答発生]
       │
       ▼
[IndexedDB Outbox キューへ追加]
       │
       ├─── 状態: PENDING (未同期)
       │
[通信状態の監視 (navigator.onLine / Service Worker SyncManager)]
       │
       ├─── オンライン復帰イベント検知
       │
       ▼
[POST /api/v1/quiz/answers/batch (一括送信)]
       │
       ├─── 成功 (200 OK)
       │       └── キューから削除、ユーザー統計（正答率）を再計算
       │
       └─── 失敗 (ネットワーク不安定)
               └── 指数バックオフ (Exponential Backoff) で再試行
```

---

## 5. Service Worker 実装仕様 (Workbox 連携)

Next.js 15 PWA プラグイン（`@serwist/next` または Workbox）を用いて以下のルーティングを設定します。

```typescript
// 1. 不変画像アセット: Cache-First (永久)
registerRoute(
  ({ url }) => url.pathname.startsWith('/images/members/'),
  new CacheFirst({
    cacheName: 'member-images-cache',
    plugins: [
      new ExpirationPlugin({
        maxEntries: 200,
        maxAgeSeconds: 30 * 24 * 60 * 60, // 30日
      }),
    ],
  })
);

// 2. マスタ同期 API: Network-First with Offline Fallback
registerRoute(
  ({ url }) => url.pathname === '/api/v1/sync/bootstrap',
  new NetworkFirst({
    cacheName: 'master-data-cache',
    networkTimeoutSeconds: 2, // 2秒で諦めてローカルキャッシュを使用
  })
);
```

---

## 6. 参考文献・公式仕様

- [MDN Web Docs: Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [MDN Web Docs: Background Synchronization API](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API)
- [Workbox - Google Chrome Developers](https://developer.chrome.com/docs/workbox/)
- [Local-First Software: You own your data, in spite of the cloud (Ink & Switch)](https://www.inkandswitch.com/local-first/)
