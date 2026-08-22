# Go & TypeScript (Node.js) 固有の高速化テクニック (08_language_tuning_go_ts.md)

ISUCONにおける2大採用言語（Go / TypeScript）に特化したチューニングの勘所です。

---

## 🐹 1. Go言語のチューニングテクニック

### ① DBコネクションプールの最適化 (`database/sql`)
デフォルト設定では高負荷時にコネクションの切断・再接続が多発しボトルネックになります。

```go
db, err := sqlx.Open("mysql", dsn)
if err != nil {
    log.Fatal(err)
}

// 接続プールのチューニング (重要)
db.SetMaxOpenConns(100)           // 最大接続数
db.SetMaxIdleConns(100)           // アイドル接続数 (MaxOpenConnsと同値にして切断を防ぐ)
db.SetConnMaxLifetime(5 * time.Minute)
```

### ② 高速なJSONライブラリの利用
Go標準の `encoding/json` はリフレクションを多用するためCPUを喰います。ドロップインで置き換え可能な高速ライブラリを使います。

```go
// goccy/go-json または json-iterator/go
import "github.com/goccy/go-json"

// encoding/json と同じAPIで約2〜3倍高速
data, err := json.Marshal(v)
```

### ③ `sync.Pool` によるメモリアロケーション削減
大量に生成・破棄されるバッファ（`bytes.Buffer`）や構造体は `sync.Pool` で再利用し、GC（ガベージコレクション）の圧力を下げます。

```go
var bufPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}

func Process() {
    buf := bufPool.Get().(*bytes.Buffer)
    buf.Reset()
    defer bufPool.Put(buf)

    // buf を使用
}
```

---

## 🟩 2. TypeScript / Node.js のチューニングテクニック

### ① 【最重要】Node.jsのマルチプロセス化 (CPU全コアの活用)
Node.jsはシングルスレッド動作のため、そのままでは1つのCPUコアしか使えません。サーバーが4コアあれば、**PM2** または **Node標準の `cluster` モジュール** で4プロセス立ち上げます。

#### PM2 を使う場合:
```bash
# クラスターモードで全コア起動
npx pm2 start dist/index.js -i max --name "isucon-app"
```

#### Nginx 側で分散させる場合 (複数ポートで起動):
```nginx
upstream app {
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
    server 127.0.0.1:8003;
    server 127.0.0.1:8004;
    keepalive 64;
}
```

### ② メモリ上限の拡張
Node.jsのデフォルトヒープ上限（約1.4GB〜2GB）でOOMが発生するのを防ぐため、メモリ上限を引き上げます。

```bash
# 4GBまで拡張
NODE_OPTIONS="--max-old-space-size=4096" node dist/index.js
```

### ③ ORMの回避と生SQL (`mysql2/promise`)
Prisma や TypeORM などの重厚なORMは、オブジェクトマッピング処理で膨大なCPUとメモリを消費します。
ISUCONでは `mysql2/promise` による生SQL + プリペアドステートメントが最も高速です。

```typescript
import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.MYSQL_HOST || '127.0.0.1',
  user: 'isucon',
  password: 'password',
  database: 'isucon',
  connectionLimit: 50,
  waitForConnections: true,
});

// クエリ実行
const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [userId]);
```

### ④ インメモリキャッシュの実装
シンプルな `Map` や `lru-cache` を使用します。

```typescript
const userCache = new Map<number, User>();

async function getUser(id: number): Promise<User> {
  if (userCache.has(id)) {
    return userCache.get(id)!;
  }
  const [rows]: any = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
  if (rows.length > 0) {
    userCache.set(id, rows[0]);
    return rows[0];
  }
  throw new Error('Not found');
}
```
