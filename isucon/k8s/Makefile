# ==============================================================================
# ISUCON Kubernetes サンドボックス Makefile
# ==============================================================================

NAMESPACE := isucon
ALP_MATCH := "/api/posts/[0-9]+"

.PHONY: help build-image deploy delete bench alp slow pprof port-forward status logs-nginx logs-app

help:
	@echo "利用可能な Kubernetes ISUCON コマンド:"
	@echo "  make build-image  - Go アプリのDockerイメージをビルド (isucon-app:latest)"
	@echo "  make deploy       - k8s クラスタに全リソース (Namespace/Nginx/App/MySQL) をデプロイ"
	@echo "  make delete       - k8s クラスタから全リソースを削除"
	@echo "  make bench        - クラスタ内でベンチマークJobを実行 & 結果表示"
	@echo "  make alp          - Nginx Pod のアクセスログを alp で集計"
	@echo "  make slow         - MySQL Pod のスロークエリログを pt-query-digest で集計"
	@echo "  make pprof        - pprof (ポート6060) にポートフォワードしてブラウザ表示"
	@echo "  make status       - Pod / Service / Ingress の状態確認"

build-image:
	docker build -t isucon-app:latest ../local-sandbox/app-go
	@echo "✓ Docker image 'isucon-app:latest' built."
	@echo "💡 kindクラスタをご利用の場合: kind load docker-image isucon-app:latest"
	@echo "💡 minikubeをご利用の場合: minikube image load isucon-app:latest"

deploy:
	kubectl apply -k .
	@echo "==> デプロイ完了。Podの起動を待機中..."
	@kubectl rollout status deployment/mysql -n $(NAMESPACE) --timeout=60s || true
	@kubectl rollout status deployment/app -n $(NAMESPACE) --timeout=60s || true
	@kubectl rollout status deployment/nginx -n $(NAMESPACE) --timeout=60s || true
	@echo "==> 準備完了！"

delete:
	kubectl delete -k .

status:
	kubectl get pods,svc,ingress -n $(NAMESPACE)

bench:
	@echo "==> ベンチマークJobを実行します..."
	@kubectl delete job isucon-benchmarker -n $(NAMESPACE) --ignore-not-found=true > /dev/null
	@kubectl apply -f benchmark/job.yaml -n $(NAMESPACE)
	@echo "==> ベンチマーク実行中 (ログ追従)..."
	@kubectl wait --for=condition=ready pod -l job-name=isucon-benchmarker -n $(NAMESPACE) --timeout=30s > /dev/null || true
	@kubectl logs -f job/isucon-benchmarker -n $(NAMESPACE)

alp:
	@echo "==> Nginx アクセスログを取得して集計中..."
	@NGINX_POD=$$(kubectl get pod -l app=nginx -n $(NAMESPACE) -o jsonpath="{.items[0].metadata.name}"); \
	kubectl exec $$NGINX_POD -n $(NAMESPACE) -c nginx -- cat /var/log/nginx/access.log | \
	if command -v alp > /dev/null; then \
		alp ltsv --sort=sum -r -m $(ALP_MATCH); \
	else \
		docker run --rm -i tkuchiki/alp:latest ltsv --sort=sum -r -m $(ALP_MATCH); \
	fi

slow:
	@echo "==> MySQL スロークエリログを取得して解析中..."
	@MYSQL_POD=$$(kubectl get pod -l app=mysql -n $(NAMESPACE) -o jsonpath="{.items[0].metadata.name}"); \
	kubectl exec $$MYSQL_POD -n $(NAMESPACE) -c mysql -- cat /var/log/mysql/mysql-slow.log | \
	docker run --rm -i percona/percona-toolkit:latest pt-query-digest | head -n 45

pprof:
	@echo "==> pprof (ポート6060) へポートフォワードを開始します (Ctrl+C で終了)..."
	@echo "💡 ブラウザで http://localhost:6060/debug/pprof/ を開いてください"
	@kubectl port-forward svc/app 6060:6060 -n $(NAMESPACE)
