#!/usr/bin/env bash
# ==============================================================================
# setup-local.sh - ISUCON ローカル模擬環境の自動生成・複製スクリプト
# ==============================================================================
set -euo pipefail

TARGET_DIR="${1:-./isucon-sandbox-local}"

echo "📦 Generating ISUCON Local Sandbox at: $TARGET_DIR"
mkdir -p "$TARGET_DIR"/{nginx,mysql/initdb.d,app-go,benchmark,logs/nginx,logs/mysql}

# 1. docker-compose.yml
cat << 'EOF' > "$TARGET_DIR/docker-compose.yml"
version: '3.8'

services:
  nginx:
    image: nginx:1.25-alpine
    ports:
      - "127.0.0.1:80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - app
    restart: always

  app:
    build:
      context: ./app-go
      dockerfile: Dockerfile
    ports:
      - "127.0.0.1:8000:8000"
      - "127.0.0.1:6060:6060"
    environment:
      - MYSQL_HOST=mysql
      - MYSQL_PORT=3306
      - MYSQL_USER=isucon
      - MYSQL_PASSWORD=isucon
      - MYSQL_DATABASE=isucon
    depends_on:
      mysql:
        condition: service_healthy
    restart: always

  mysql:
    image: mysql:8.0
    ports:
      - "127.0.0.1:3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=isucon
      - MYSQL_USER=isucon
      - MYSQL_PASSWORD=isucon
    volumes:
      - ./mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro
      - ./mysql/initdb.d:/docker-entrypoint-initdb.d:ro
      - ./logs/mysql:/var/log/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "isucon", "-pisucon"]
      interval: 3s
      timeout: 3s
      retries: 10
    restart: always
EOF

# 2. nginx.conf
cat << 'EOF' > "$TARGET_DIR/nginx/nginx.conf"
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

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
    error_log /var/log/nginx/error.log warn;

    sendfile on;
    keepalive_timeout 65;

    upstream app {
        server app:8000;
        keepalive 32;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
EOF

# 3. my.cnf
cat << 'EOF' > "$TARGET_DIR/mysql/my.cnf"
[mysqld]
default-authentication-plugin=mysql_native_password
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 0.0
log_queries_not_using_indexes = 1

innodb_buffer_pool_size = 512M
innodb_flush_log_at_trx_commit = 2
EOF

# 4. 00_schema.sql
cat << 'EOF' > "$TARGET_DIR/mysql/initdb.d/00_schema.sql"
DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE posts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'published',
    view_count INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE comments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    body TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELIMITER //
CREATE PROCEDURE InsertSampleData()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE u_id BIGINT;
    DECLARE p_id BIGINT;

    WHILE i <= 100 DO
        INSERT INTO users (name, email) VALUES (CONCAT('User_', i), CONCAT('user_', i, '@example.com'));
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 1000 DO
        SET u_id = 1 + (i % 100);
        INSERT INTO posts (user_id, title, content, status, view_count, created_at)
        VALUES (u_id, CONCAT('Title ', i), CONCAT('This is content for post number ', i), IF(i % 5 = 0, 'draft', 'published'), i * 7, DATE_SUB(NOW(), INTERVAL i MINUTE));
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 3000 DO
        SET p_id = 1 + (i % 1000);
        SET u_id = 1 + (i % 100);
        INSERT INTO comments (post_id, user_id, body)
        VALUES (p_id, u_id, CONCAT('Comment body for comment ', i));
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL InsertSampleData();
DROP PROCEDURE InsertSampleData;
EOF

# 5. app-go
cat << 'EOF' > "$TARGET_DIR/app-go/go.mod"
module isucon-sandbox

go 1.22

require (
	github.com/go-sql-driver/mysql v1.8.1
	github.com/jmoiron/sqlx v1.4.0
)

require filippo.io/edwards25519 v1.1.0 // indirect
EOF

cat << 'EOF' > "$TARGET_DIR/app-go/Dockerfile"
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download || true
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server .

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/server /app/server
EXPOSE 8000 6060
CMD ["/app/server"]
EOF

cat << 'EOF' > "$TARGET_DIR/app-go/main.go"
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	_ "net/http/pprof"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
)

var db *sqlx.DB

type User struct {
	ID        int64     `db:"id" json:"id"`
	Name      string    `db:"name" json:"name"`
	Email     string    `db:"email" json:"email"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

type Post struct {
	ID           int64     `db:"id" json:"id"`
	UserID       int64     `db:"user_id" json:"user_id"`
	Title        string    `db:"title" json:"title"`
	Content      string    `db:"content" json:"content"`
	Status       string    `db:"status" json:"status"`
	ViewCount    int       `db:"view_count" json:"view_count"`
	CreatedAt    time.Time `db:"created_at" json:"created_at"`
	UserName     string    `json:"user_name,omitempty"`
	CommentCount int       `json:"comment_count"`
}

type Comment struct {
	ID        int64     `db:"id" json:"id"`
	PostID    int64     `db:"post_id" json:"post_id"`
	UserID    int64     `db:"user_id" json:"user_id"`
	Body      string    `db:"body" json:"body"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

func initDB() {
	host := os.Getenv("MYSQL_HOST")
	if host == "" { host = "127.0.0.1" }
	port := os.Getenv("MYSQL_PORT")
	if port == "" { port = "3306" }
	user := os.Getenv("MYSQL_USER")
	if user == "" { user = "isucon" }
	pass := os.Getenv("MYSQL_PASSWORD")
	if pass == "" { pass = "isucon" }
	dbname := os.Getenv("MYSQL_DATABASE")
	if dbname == "" { dbname = "isucon" }

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&loc=Local", user, pass, host, port, dbname)
	var err error
	db, err = sqlx.Connect("mysql", dsn)
	if err != nil { log.Fatalf("Failed to connect to MySQL: %v", err) }
	db.SetMaxOpenConns(50)
	db.SetMaxIdleConns(50)
}

func handleGetPosts(w http.ResponseWriter, r *http.Request) {
	var posts []Post
	err := db.Select(&posts, "SELECT id, user_id, title, content, status, view_count, created_at FROM posts WHERE status = 'published' ORDER BY created_at DESC LIMIT 30")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	for i := range posts {
		var user User
		if err := db.Get(&user, "SELECT name FROM users WHERE id = ?", posts[i].UserID); err != nil && err != sql.ErrNoRows {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		posts[i].UserName = user.Name

		var count int
		if err := db.Get(&count, "SELECT COUNT(*) FROM comments WHERE post_id = ?", posts[i].ID); err != nil && err != sql.ErrNoRows {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		posts[i].CommentCount = count
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(posts)
}

func handleGetPostDetail(w http.ResponseWriter, r *http.Request) {
	idStr := strings.TrimPrefix(r.URL.Path, "/api/posts/")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "Invalid post ID", http.StatusBadRequest)
		return
	}
	var post Post
	err = db.Get(&post, "SELECT * FROM posts WHERE id = ?", id)
	if err == sql.ErrNoRows {
		http.Error(w, "Post not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	var comments []Comment
	if err := db.Select(&comments, "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at ASC", id); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"post": post,
		"comments": comments,
	})
}

func handleHeavyCalc(w http.ResponseWriter, r *http.Request) {
	text := "ISUCON is a competition where you speed up web applications to the maximum limit!"
	matchCount := 0
	for i := 0; i < 5000; i++ {
		re := regexp.MustCompile(`(ISUCON|applications|limit)`)
		if re.MatchString(text) { matchCount++ }
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"result": "ok", "count": matchCount})
}

func main() {
	initDB()
	go func() { _ = http.ListenAndServe("0.0.0.0:6060", nil) }()
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK); w.Write([]byte("OK")) })
	mux.HandleFunc("/api/posts", handleGetPosts)
	mux.HandleFunc("/api/posts/", handleGetPostDetail)
	mux.HandleFunc("/api/heavy-calc", handleHeavyCalc)
	_ = http.ListenAndServe(":8000", mux)
}
EOF

# 6. benchmark/bench.sh
cat << 'EOF' > "$TARGET_DIR/benchmark/bench.sh"
#!/usr/bin/env bash
set -euo pipefail
TARGET_URL="${1:-http://localhost:80}"
DURATION_SEC="${2:-10}"
CONCURRENCY=5

echo "🚀 ベンチマーク開始: ${TARGET_URL} (${DURATION_SEC}秒, 並行数: ${CONCURRENCY})"
END_TIME=$(( $(date +%s) + DURATION_SEC ))
TOTAL=0; SUCCESS=0; FAIL=0

run_worker() {
    local id=$1; local ok=0; local ng=0
    while [ $(date +%s) -lt $END_TIME ]; do
        curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/posts" > /dev/null && ok=$((ok+1)) || ng=$((ng+1))
        post_id=$(( (RANDOM % 20) + 1 ))
        curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/posts/${post_id}" > /dev/null && ok=$((ok+1)) || ng=$((ng+1))
        curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/heavy-calc" > /dev/null && ok=$((ok+1)) || ng=$((ng+1))
    done
    echo "${ok},${ng}" > "/tmp/bench_res_${id}.txt"
}

for i in $(seq 1 $CONCURRENCY); do run_worker $i & done
wait

for i in $(seq 1 $CONCURRENCY); do
    if [ -f "/tmp/bench_res_${i}.txt" ]; then
        IFS=',' read -r ok ng < "/tmp/bench_res_${i}.txt"
        SUCCESS=$((SUCCESS+ok)); FAIL=$((FAIL+ng)); TOTAL=$((TOTAL+ok+ng))
        rm -f "/tmp/bench_res_${i}.txt"
    fi
done

QPS=$(( TOTAL / DURATION_SEC ))
SCORE=$(( SUCCESS * 10 - FAIL * 50 ))
echo "🏁 終了 | 総Req: ${TOTAL} | 成功: ${SUCCESS} | 失敗: ${FAIL} | QPS: ${QPS} | スコア: ${SCORE}"
EOF
chmod +x "$TARGET_DIR/benchmark/bench.sh"

# 7. Makefile
cat << 'EOF' > "$TARGET_DIR/Makefile"
ALP_MATCH := "/api/posts/[0-9]+"

.PHONY: up down bench clean-logs alp slow pprof status

up:
	mkdir -p logs/nginx logs/mysql
	docker compose up -d --build
	@sleep 5

down:
	docker compose down -v

clean-logs:
	@rm -f logs/nginx/access.log logs/mysql/mysql-slow.log
	@docker compose exec -T nginx nginx -s reopen || true
	@docker compose exec -T mysql mysql -u root -proot -e "FLUSH SLOW LOGS;" || true

bench: clean-logs
	@./benchmark/bench.sh http://localhost:80 10

alp:
	@docker run --rm -v $(PWD)/logs/nginx:/var/log/nginx tkuchiki/alp:latest ltsv --file=/var/log/nginx/access.log --sort=sum -r -m $(ALP_MATCH)

slow:
	@docker run --rm -v $(PWD)/logs/mysql:/var/log/mysql percona/percona-toolkit:latest pt-query-digest /var/log/mysql/mysql-slow.log | head -n 45

pprof:
	@go tool pprof -http=localhost:1080 http://localhost:6060/debug/pprof/profile?seconds=10 || echo "Go not found or pprof error."

status:
	docker compose ps
EOF

echo "✓ ISUCON Local Sandbox created at '$TARGET_DIR'!"
echo "💡 Start with: cd $TARGET_DIR && make up && make bench"
