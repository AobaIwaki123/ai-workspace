package main

import (
	"database/sql"
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"net/http/pprof"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
)

//go:embed public/*
var publicFS embed.FS

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
	if host == "" {
		host = "127.0.0.1"
	}
	port := os.Getenv("MYSQL_PORT")
	if port == "" {
		port = "3306"
	}
	user := os.Getenv("MYSQL_USER")
	if user == "" {
		user = "isucon"
	}
	pass := os.Getenv("MYSQL_PASSWORD")
	if pass == "" {
		pass = "isucon"
	}
	dbname := os.Getenv("MYSQL_DATABASE")
	if dbname == "" {
		dbname = "isucon"
	}

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&loc=Local", user, pass, host, port, dbname)
	var err error
	db, err = sqlx.Connect("mysql", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to MySQL: %v", err)
	}

	// コネクション設定
	db.SetMaxOpenConns(50)
	db.SetMaxIdleConns(50)
}

// 事前コンパイルした正規表現（CPU ボトルネック解消）
var heavyCalcRegex = regexp.MustCompile(`(ISUCON|applications|limit)`)

// ✅ チューニング済み: N+1 クエリ解消（一括 IN クエリで 31回 -> 3回に削減）
func handleGetPosts(w http.ResponseWriter, r *http.Request) {
	// 1. 投稿一覧を取得 (複合インデックス idx_status_created_at で高速取得)
	var posts []Post
	err := db.Select(&posts, "SELECT id, user_id, title, content, status, view_count, created_at FROM posts WHERE status = 'published' ORDER BY created_at DESC LIMIT 30")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if len(posts) == 0 {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(posts)
		return
	}

	// 2. ユーザーIDと投稿IDを収集
	userIDs := make([]int64, 0, len(posts))
	postIDs := make([]int64, 0, len(posts))
	for _, p := range posts {
		userIDs = append(userIDs, p.UserID)
		postIDs = append(postIDs, p.ID)
	}

	// 3. ユーザー名を一括取得 (1クエリ)
	userQuery, userArgs, err := sqlx.In("SELECT id, name FROM users WHERE id IN (?)", userIDs)
	if err == nil {
		var users []User
		if err := db.Select(&users, userQuery, userArgs...); err == nil {
			userMap := make(map[int64]string, len(users))
			for _, u := range users {
				userMap[u.ID] = u.Name
			}
			for i := range posts {
				posts[i].UserName = userMap[posts[i].UserID]
			}
		}
	}

	// 4. コメント数を一括集計 (1クエリ: GROUP BY & idx_post_id)
	type CommentCount struct {
		PostID int64 `db:"post_id"`
		Count  int   `db:"cnt"`
	}
	commentQuery, commentArgs, err := sqlx.In("SELECT post_id, COUNT(*) as cnt FROM comments WHERE post_id IN (?) GROUP BY post_id", postIDs)
	if err == nil {
		var counts []CommentCount
		if err := db.Select(&counts, commentQuery, commentArgs...); err == nil {
			countMap := make(map[int64]int, len(counts))
			for _, c := range counts {
				countMap[c.PostID] = c.Count
			}
			for i := range posts {
				posts[i].CommentCount = countMap[posts[i].ID]
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(posts)
}

// ✅ チューニング済み: PK & idx_post_id による高速取得
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

	// コメント一覧 (idx_post_id で高速取得)
	var comments []Comment
	if err := db.Select(&comments, "SELECT * FROM comments WHERE post_id = ? ORDER BY created_at ASC", id); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"post":     post,
		"comments": comments,
	})
}

// ✅ チューニング済み: 事前コンパイル正規表現で CPU 負荷を 99% 削減
func handleHeavyCalc(w http.ResponseWriter, r *http.Request) {
	text := "ISUCON is a competition where you speed up web applications to the maximum limit!"
	matchCount := 0

	for i := 0; i < 5000; i++ {
		if heavyCalcRegex.MatchString(text) {
			matchCount++
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"result": "ok",
		"count":  matchCount,
	})
}

func main() {
	initDB()
	log.Println("Database connected successfully.")

	// pprof を別ポート (6060) で起動
	go func() {
		log.Println("Starting pprof on :6060")
		if err := http.ListenAndServe("0.0.0.0:6060", nil); err != nil {
			log.Printf("pprof server error: %v", err)
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	mux.HandleFunc("/api/posts", handleGetPosts)
	mux.HandleFunc("/api/posts/", handleGetPostDetail)
	mux.HandleFunc("/api/heavy-calc", handleHeavyCalc)

	// pprof ハンドラをメイン mux にも登録
	mux.HandleFunc("/debug/pprof/", pprof.Index)
	mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("/debug/pprof/trace", pprof.Trace)

	// 静的フロントエンド配信 (index.html)
	if subFS, err := fs.Sub(publicFS, "public"); err == nil {
		mux.Handle("/", http.FileServer(http.FS(subFS)))
	}

	// リクエストログ出力ミドルウェア
	loggedHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		mux.ServeHTTP(w, r)
		// 静的アセット以外の API リクエストをログ出力
		if strings.HasPrefix(r.URL.Path, "/api/") || r.URL.Path == "/health" {
			log.Printf("📥 [%s] %s -> completed in %v (Remote: %s)", r.Method, r.URL.Path, time.Since(start), r.RemoteAddr)
		}
	})

	server := &http.Server{
		Addr:    ":8000",
		Handler: loggedHandler,
	}

	log.Println("Starting API server on :8000")
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
