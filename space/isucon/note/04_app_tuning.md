# アプリケーションチューニングの定石パターン (04_app_tuning.md)

ISUCONでスコアを爆発的に伸ばすためのアプリケーション・SQL改善パターンです。

---

## 1. N+1 クエリの解消

最も頻出するボトルネック。ループ内で1行ずつSELECTしている箇所を一括取得（`IN` 句）に変更します。

### ❌ 改善前 (N+1クエリ)
```go
// 記事一覧を取得 (1回)
posts, _ := db.Query("SELECT id, user_id, title FROM posts LIMIT 50")
for _, p := range posts {
    // 記事ごとにユーザー情報を取得 (50回クエリが飛ぶ！)
    var u User
    db.QueryRow("SELECT name, icon FROM users WHERE id = ?", p.UserID).Scan(&u.Name, &u.Icon)
    p.User = u
}
```

### ⭕ 改善後 (IN句による一括取得)
```go
// 1. 記事一覧を取得
posts, _ := getPosts()

// 2. 登場する user_id を収集 (重複除外)
userIDs := extractUserIDs(posts)

// 3. IN句で一括取得 (1クエリで完了)
// SELECT id, name, icon FROM users WHERE id IN (?, ?, ...)
usersMap, _ := getUsersByIDs(userIDs)

// 4. メモリ上で紐付け
for i := range posts {
    posts[i].User = usersMap[posts[i].UserID]
}
```

---

## 2. 適切な INDEX（インデックス）の付与

スロークエリログで `log_queries_not_using_indexes` に出ているもの、または `EXPLAIN` で `type: ALL`（Full Table Scan）になっているものにインデックスを貼ります。

### 基本ルール
1. **WHERE句・JOIN句・ORDER BY句** で使われるカラムに貼る。
2. **複合インデックスの順序**:
   - `WHERE status = ? AND created_at > ? ORDER BY created_at DESC` の場合
   - `CREATE INDEX idx_status_created_at ON items (status, created_at);`
   - **等値比較 (`=`) のカラムを先頭に、範囲検索・ソートのカラムを後ろにする**のが鉄則。

```sql
-- テーブル定義への追加例
ALTER TABLE comments ADD INDEX idx_post_id_created_at (post_id, created_at DESC);
```

---

## 3. インメモリキャッシュ (Go: `sync.Map` / `sync.RWMutex`)

マスターデータ（都道府県一覧、ユーザー名・アイコンなど）や更新頻度が低いデータをプロセス内メモリにキャッシュします。

```go
type UserCache struct {
    sync.RWMutex
    items map[int64]User
}

var userCache = UserCache{items: make(map[int64]User)}

func GetUserCached(id int64) (User, error) {
    userCache.RLock()
    if u, ok := userCache.items[id]; ok {
        userCache.RUnlock()
        return u, nil
    }
    userCache.RUnlock()

    // DBから取得
    u, err := fetchUserFromDB(id)
    if err != nil {
        return User{}, err
    }

    userCache.Lock()
    userCache.items[id] = u
    userCache.Unlock()

    return u, nil
}
```

> [!WARNING]
> 複数台構成にした場合、プロセス内インメモリキャッシュはサーバー間で共有されません。更新が発生するデータは整合性エラー（Fail）になりやすいので注意してください（更新時にキャッシュを破棄するか、Redis等の外部キャッシュを利用する）。

---

## 4. SingleFlight による重複クエリの抑制

Go言語の `golang.org/x/sync/singleflight` を使うと、同一キーに対する同時リクエストを1回のリクエストにまとめて実行し、結果を共有できます（キャッシュスタンピード対策）。

```go
import "golang.org/x/sync/singleflight"

var sfg singleflight.Group

func GetHotItem(itemID int64) (*Item, error) {
    key := fmt.Sprintf("item:%d", itemID)
    v, err, _ := sfg.Do(key, func() (interface{}, error) {
        return fetchItemFromDB(itemID)
    })
    if err != nil {
        return nil, err
    }
    return v.(*Item), nil
}
```

---

## 5. BULK INSERT / BULK UPDATE

複数行のINSERTを1回にまとめることで、ネットワークラウンドトリップとトランザクションコミットのオーバーヘッドを削減します。

```sql
-- 1行ずつ INSERT (遅い)
INSERT INTO logs (user_id, action) VALUES (1, 'view');
INSERT INTO logs (user_id, action) VALUES (2, 'view');

-- BULK INSERT (圧倒的に速い)
INSERT INTO logs (user_id, action) VALUES (1, 'view'), (2, 'view');
```
