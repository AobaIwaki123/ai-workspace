# ==========================================
# ISUCON ローカル模擬環境 Makefile
# ==========================================

ALP_MATCH := "/api/posts/[0-9]+"

.PHONY: help up down restart logs bench clean-logs alp slow pprof status measure

help:
	@echo "ISUCON ローカル測定ハンズオン コマンド一覧:"
	@echo "  make up          - ローカル環境 (Nginx, Go App, MySQL) の起動"
	@echo "  make down        - ローカル環境の停止・削除"
	@echo "  make restart     - コンテナの再起動"
	@echo "  make bench       - 模擬ベンチマークの実行 (10秒間負荷生成)"
	@echo "  make measure     - ⭐ bench + alp + slow を一発実行 & 結果保存 & 前回比較"
	@echo "  make clean-logs  - Nginx & MySQL ログのクリア"
	@echo "  make alp         - alpによるNginxアクセスログ集計 (sum降順)"
	@echo "  make slow        - pt-query-digestによるMySQLスロークエリ集計"
	@echo "  make pprof       - Goのpprofプロファイルを取得してブラウザで表示"
	@echo "  make status      - コンテナのヘルスチェック状態確認"

up:
	mkdir -p logs/nginx logs/mysql
	docker compose up -d --build
	@echo "==> サービス起動完了。MySQLの初期データ投入を待機しています..."
	@sleep 5
	@echo "==> 準備完了: http://localhost:8080 (Nginx) / http://localhost:6060/debug/pprof/ (pprof)"

down:
	docker compose down -v

restart:
	docker compose restart

clean-logs:
	@echo "==> ログをクリアします..."
	@rm -f logs/nginx/access.log logs/mysql/mysql-slow.log
	@docker compose exec -T nginx nginx -s reopen || true
	@docker compose exec -T mysql mysql -u root -proot -e "FLUSH SLOW LOGS;" || true
	@echo "==> ログクリア完了！"

bench: clean-logs
	@./benchmark/bench.sh http://localhost:8080 10

alp:
	@if command -v alp > /dev/null; then \
		alp ltsv --file=logs/nginx/access.log --sort=sum -r -m $(ALP_MATCH); \
	else \
		echo "alpがローカルに見つかりません。Docker経由で実行します..."; \
		docker run --rm -v $(PWD)/logs/nginx:/var/log/nginx tkuchiki/alp:latest ltsv --file=/var/log/nginx/access.log --sort=sum -r -m $(ALP_MATCH); \
	fi

slow:
	@echo "==> pt-query-digest によるスロークエリ解析結果:"
	@docker run --rm -v $(PWD)/logs/mysql:/var/log/mysql percona/percona-toolkit:latest pt-query-digest /var/log/mysql/mysql-slow.log | head -n 45

pprof:
	@echo "==> ベンチマーク実行中に10秒のCPUプロファイルを取得して可視化します..."
	@if command -v go > /dev/null; then \
		go tool pprof -http=localhost:1080 http://localhost:6060/debug/pprof/profile?seconds=10; \
	else \
		echo "❌ 'go' コマンドが見つかりません。ホストに Go をインストールするか、ブラウザで http://localhost:6060/debug/pprof/ を開いてください。"; \
	fi

status:
	docker compose ps

measure:
	@./benchmark/measure.sh http://localhost:8080 10
