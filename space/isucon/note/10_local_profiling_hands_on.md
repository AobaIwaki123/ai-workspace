# ローカルで学ぶISUCON測定ハンズオン実践ガイド (10_local_profiling_hands_on.md)

クラウドで本番演習を行う前に、手元のローカル環境（Docker Compose）で **「alp」「pt-query-digest」「pprof」を使った測定〜ボトルネック特定の全サイクル** を体験・習得するためのハンズオンガイドです。

---

## 🎯 このハンズオンで身につくこと

1. **alp の使い方**: 最も合計レスポンス時間 (`sum`) を消費している重いエンドポイントを特定する
2. **pt-query-digest の使い方**: データベースに最も負荷をかけているスロークエリを特定し、`EXPLAIN` で原因を突き止める
3. **pprof の使い方**: CPU時間を異常に消費しているコード行（関数）をフレームグラフ（FlameGraph）で可視化する
4. **「推測するな、計測せよ」のサイクル**: 測定データに基づいて改善を行い、スコアが上がる瞬間を体感する

---

## 🚀 ステップ1: ローカル模擬環境の起動

```bash
cd isucon/local-sandbox
make up
```

起動後、以下にアクセスできることを確認します:
- **Webアプリ (via Nginx)**: `http://localhost/api/posts`
- **pprof プロファイラ**: `http://localhost:6060/debug/pprof/`

---

## 📊 ステップ2: 負荷をかけて測定データを生成する

```bash
make bench
```
10秒間の並行負荷テストが走り、NginxアクセスログとMySQLスロークエリログが生成されます。

---

## 🔍 ステップ3: 3大測定ツールによるボトルネック特定

### ① alp で重いエンドポイントを特定 (`make alp`)

```bash
make alp
```

#### 出力の見方・着眼点:
```
+-------+-----+------+-----+-----+-----+--------+------------------------+
| COUNT | 1XX | 2XX  | 3XX | 4XX | 5XX |  SUM   |          URI           |
+-------+-----+------+-----+-----+-----+--------+------------------------+
|   150 |   0 |  150 |   0 |   0 |   0 | 18.450 | /api/posts             | <- 🔴 最も重い (Sum 1位)
|   150 |   0 |  150 |   0 |   0 |   0 | 12.100 | /api/heavy-calc        | <- 🟡 CPUボトルネック
|   150 |   0 |  150 |   0 |   0 |   0 |  4.200 | /api/posts/[0-9]+      | <- 🟢 次の候補
+-------+-----+------+-----+-----+-----+--------+------------------------+
```
- **`SUM`（合計所要時間）**: ここが最大のものが全体の足を引っ張っている。最優先で改善対象にする。
- **`-m` オプション**: `/api/posts/1`, `/api/posts/2` を `/api/posts/[0-9]+` に正規表現でまとめることで、正確な合算値が見える。

---

### ② pt-query-digest でスロークエリを特定 (`make slow`)

```bash
make slow
```

#### 出力の見方・着眼点:
```
# Profile
# Rank Query ID           Response time  Calls R/Call   V/M   Item
# ==== ================== ============== ===== ======== ===== =================
#    1 0x4B3A8F9C12345678 12.5400  68.2%  4500   0.0028  0.00 SELECT comments
#    2 0x9D8E7C6B54321098  3.2100  17.4%   150   0.0214  0.00 SELECT posts
```
- **`Response time %`**: 全クエリ実行時間の何割を占めているか。上記では **68.2%** が `comments` のカウントクエリ。
- **`Calls`**: 4,500回呼ばれている → **典型的な N+1 クエリ！**
- **次のアクション**:
  - `comments.post_id` にインデックスがないため、Full Table Scan が 4,500回発生している。
  - アプリケーション側で `IN` 句を使って一括集計するか、`post_id` にインデックスを追加する。

---

### ③ pprof でCPUボトルネックを可視化 (`make pprof`)

GoアプリケーションがCPUを消費している箇所をグラフィカルに特定します。

```bash
# ベンチマークを回しながら別ターミナルで実行
make pprof
```
ブラウザが自動的に開き（`http://localhost:1080/ui/`）、**FlameGraph（フレームグラフ）** や **Top関数一覧** が表示されます。

- **FlameGraphの読み方**: 横幅が広いボックスほど、多くのCPU時間を消費しています。
- 今回の環境では `regexp.MustCompile` がCPUの大部分を占めていることが一目でわかります。

---

## 🛠️ ステップ4: 改善演習（ハンズオン課題）

ローカル環境のボトルネックを解消してみましょう！

1. **MySQLにインデックスを貼る**:
   ```sql
   ALTER TABLE posts ADD INDEX idx_status_created_at (status, created_at DESC);
   ALTER TABLE comments ADD INDEX idx_post_id (post_id);
   ```
2. **`app-go/main.go` の N+1 を解消する**:
   - ユーザー名取得: 投稿に含まれる `user_id` を収集し、`SELECT id, name FROM users WHERE id IN (...)` で一括取得してメモリ上でマッピング。
   - コメント数取得: `SELECT post_id, COUNT(*) FROM comments WHERE post_id IN (...) GROUP BY post_id` で一括取得。
3. **`app-go/main.go` の正規表現を事前コンパイルする**:
   - `var re = regexp.MustCompile(...)` としてループ外に逃がす。
4. **再度 `make bench` を実行**:
   - スコアが大幅に向上したことを確認！

---

## 🧹 ステップ5: 環境のクリーンアップ

```bash
make down
```
これでコンテナとボリュームが安全に停止・削除されます。
