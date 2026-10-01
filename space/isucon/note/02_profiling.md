# 計測・プロファイリング実践ガイド (02_profiling.md)

ISUCONにおけるボトルネック特定のための三種の神器（+α）の設定と使い方をまとめます。

---

## 🛠️ 計測ツール一覧

| ツール | 対象 | わかること |
| :--- | :--- | :--- |
| **alp** | Nginx (HTTPアクセスログ) | どのエンドポイントが遅いか、呼び出し回数が多いか、レスポンスタイムの総和が大きいか |
| **pt-query-digest** | MySQL (スロークエリログ) | どのクエリが実行回数・合計実行時間が多く、負荷をかけているか |
| **pprof** (Go) / **py-spy** (Python) | アプリケーションプロセス | CPU時間やメモリを消費している関数・処理 |
| **htop / dstat / top** | サーバー全体 | CPU使用率 (User/System/IOWait)、メモリ消費、ディスクI/O、ネットワーク帯域 |

---

## 1. alp (Nginx アクセスログ解析)

### Nginx側のログフォーマット設定 (`/etc/nginx/nginx.conf`)
LTSV (Labeled Tab-Separated Values) 形式で出力するように設定します。

```nginx
http {
    log_format ltsv "time:$time_local"
                    "\thost:$remote_addr"
                    "\tforwardedfor:$http_x_forwarded_for"
                    "\treq:$request"
                    "\tstatus:$status"
                    "\tmethod:$request_method"
                    "\turi:$request_uri"
                    "\tsize:$body_bytes_sent"
                    "\treqsize:$request_length"
                    "\treferer:$http_referer"
                    "\tua:$http_user_agent"
                    "\tvhost:$host"
                    "\tapptime:$upstream_response_time"
                    "\treqtime:$request_time"
                    "\truntime:$upstream_http_x_runtime"
                    "\tkpi:$upstream_http_x_kpi";

    access_log /var/log/nginx/access.log ltsv;
    ...
}
```

### alp の実行コマンド
エンドポイント内の可変パラメータ（IDなど）を正規表現でまとめる（マッチング）のが鉄則です。

```bash
# 合計応答時間 (sum) 降順で表示
sudo alp ltsv --file=/var/log/nginx/access.log \
  --sort=sum \
  -r -m "/api/users/[0-9]+,/api/items/[0-9]+"

# 平均応答時間 (avg) 降順で表示
sudo alp ltsv --file=/var/log/nginx/access.log \
  --sort=avg \
  -r -m "/api/users/[0-9]+,/api/items/[0-9]+"

# 呼び出し回数 (count) 降順で表示
sudo alp ltsv --file=/var/log/nginx/access.log \
  --sort=count \
  -r -m "/api/users/[0-9]+,/api/items/[0-9]+"
```

> [!TIP]
> **見るべき指標**:
> - `sum` (合計時間): ここが大きいエンドポイントが全体のボトルネック（最優先で改善）。
> - `count` (回数): 異常に回数が多いなら、静的ファイル配信の漏れや無駄なポーリングの可能性。
> - `avg / max` (平均・最大時間): 重い処理（画像変換やN+1クエリ）が潜んでいる。

---

## 2. pt-query-digest (MySQL スロークエリ解析)

Percona Toolkit に含まれるツール。

### MySQL側の設定 (`/etc/mysql/my.cnf` または `/etc/mysql/mysql.conf.d/mysqld.cnf`)

```ini
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 0.0          # 0.0ですべてのクエリを記録
log_queries_not_using_indexes = 1
```

### pt-query-digest の実行コマンド

```bash
sudo pt-query-digest /var/log/mysql/mysql-slow.log | head -n 40
```

> [!TIP]
> **出力の見方**:
> - `Query ID` ごとに `Response time` の割合（%）が表示されます。
> - 最上位のクエリ（例: 全体実行時間の60%を占めているクエリ）の `EXPLAIN` を取り、インデックスが使われているか確認します。

---

## 3. pprof (Go言語のプロファイリング)

Goの場合は標準の `net/http/pprof` を組み込むだけで強力なプロファイリングが可能です。

### コードへの仕込み (`main.go`)

```go
import (
    _ "net/http/pprof"
    "net/http"
)

func main() {
    // 既存のサーバーとは別のポート（例: 6060）でpprof用HTTPサーバーを起動
    go func() {
        http.ListenAndServe("0.0.0.0:6060", nil)
    }()

    // ... 既存のアプリケーション起動処理
}
```

### プロファイルデータの取得（ベンチマーク実行中に行う）

```bash
# ベンチマーク実行中に30秒間のCPUプロファイルを取得
go tool pprof -http=:8080 http://localhost:6060/debug/pprof/profile?seconds=30
```

> [!NOTE]
> ブラウザでFlameGraph（フレームグラフ）を確認し、横幅（CPU占有率）が広い関数（JSONシリアライズ、正規表現コンパイル、パスワードハッシュ等）を特定します。

---

## 4. ログローテート・計測自動化スクリプト

ベンチマークを回すたびに、古いログを消してサービスを再起動するスクリプトを準備しておくと圧倒的に作業効率が上がります。

```bash
#!/bin/bash
set -eu

NOW=$(date +%Y%m%d%H%M%S)

# 1. ログのバックアップ & クリア
sudo mv /var/log/nginx/access.log /var/log/nginx/access.log.$NOW || true
sudo mv /var/log/mysql/mysql-slow.log /var/log/mysql/mysql-slow.log.$NOW || true

# 2. ミドルウェア & アプリ再起動
sudo systemctl restart nginx
sudo systemctl restart mysql
sudo systemctl restart isuda.go.service  # 競技のアプリサービス名

echo "Ready for benchmark!"
```
