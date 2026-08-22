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

// ❌ 意図的なボトルネック1: N+1 クエリ (投稿一覧)
func handleGetPosts(w http.ResponseWriter, r *http.Request) {
	// 1. 投稿一覧を取得 (status='published' でソート。IndexがないのでFull Scan)
	var posts []Post
	err := db.Select(&posts, "SELECT id, user_id, title, content, status, view_count, created_at FROM posts WHERE status = 'published' ORDER BY created_at DESC LIMIT 30")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// 2. N+1: 投稿ごとにユーザー名とコメント数を1件ずつクエリで取得！
	for i := range posts {
		// ユーザー名取得 (N回クエリ)
		var user User
		if err := db.Get(&user, "SELECT name FROM users WHERE id = ?", posts[i].UserID); err != nil && err != sql.ErrNoRows {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		posts[i].UserName = user.Name

		// コメント数取得 (N回クエリ & post_idにIndexがないので毎回Full Scan)
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

// ❌ 意図的なボトルネック2: スロークエリ (単一投稿詳細)
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

	// コメント一覧 (post_idにIndexなし)
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

// ❌ 意図的なボトルネック3: CPU負荷（正規表現のコンパイルループ）
func handleHeavyCalc(w http.ResponseWriter, r *http.Request) {
	text := "ISUCON is a competition where you speed up web applications to the maximum limit!"
	matchCount := 0

	// 毎回正規表現を再コンパイルする悪手 (pprofのCPUプロファイルで劇的に目立つ)
	for i := 0; i < 5000; i++ {
		re := regexp.MustCompile(`(ISUCON|applications|limit)`)
		if re.MatchString(text) {
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

	server := &http.Server{
		Addr:    ":8000",
		Handler: mux,
	}

	log.Println("Starting API server on :8000")
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}
