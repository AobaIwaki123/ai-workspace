#!/usr/bin/env bash
# ==============================================================================
# setup-k8s.sh - ISUCON Kubernetes サンドボックス (journee-style) 自動生成スクリプト
# ==============================================================================
set -euo pipefail

TARGET_DIR="${1:-./isucon-k8s}"
APP_HOST="${2:-isucon.aooba.net}"

echo "📦 Generating ISUCON Kubernetes Sandbox at: $TARGET_DIR (Host: $APP_HOST)"
mkdir -p "$TARGET_DIR"/{manifests,argocd,scripts}

# 1. manifests/kustomization.yml
cat << 'EOF' > "$TARGET_DIR/manifests/kustomization.yml"
resources:
  - mysql-configmap.yml
  - mysql-deployment.yml
  - mysql-service.yml
  - app-deployment.yml
  - app-service.yml
  - nginx-configmap.yml
  - nginx-deployment.yml
  - nginx-service.yml
  - ingress.yml
  - benchmarker-configmap.yml
EOF

# 2. manifests/app-deployment.yml & app-service.yml
cat << 'EOF' > "$TARGET_DIR/manifests/app-deployment.yml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: isucon-app
  namespace: isucon
spec:
  replicas: 1
  selector:
    matchLabels:
      app: isucon-app
  template:
    metadata:
      labels:
        app: isucon-app
    spec:
      containers:
        - name: app
          image: isucon-app:latest
          imagePullPolicy: IfNotPresent
          env:
            - name: MYSQL_HOST
              value: "isucon-mysql"
            - name: MYSQL_PORT
              value: "3306"
            - name: MYSQL_USER
              value: "isucon"
            - name: MYSQL_PASSWORD
              value: "isucon"
            - name: MYSQL_DATABASE
              value: "isucon"
          ports:
            - containerPort: 8000
              name: http
            - containerPort: 6060
              name: pprof
          resources:
            requests:
              cpu: "200m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 3
            periodSeconds: 3
EOF

cat << 'EOF' > "$TARGET_DIR/manifests/app-service.yml"
apiVersion: v1
kind: Service
metadata:
  name: isucon-app
  namespace: isucon
spec:
  selector:
    app: isucon-app
  ports:
    - name: http
      port: 8000
      targetPort: 8000
    - name: pprof
      port: 6060
      targetPort: 6060
EOF

# 3. manifests/mysql-configmap.yml, deployment, service
cat << 'EOF' > "$TARGET_DIR/manifests/mysql-configmap.yml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: isucon-mysql-cnf
  namespace: isucon
data:
  my.cnf: |
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
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: isucon-mysql-initdb
  namespace: isucon
data:
  00_schema.sql: |
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

cat << 'EOF' > "$TARGET_DIR/manifests/mysql-deployment.yml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: isucon-mysql
  namespace: isucon
  labels:
    app: isucon-mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: isucon-mysql
  template:
    metadata:
      labels:
        app: isucon-mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "root"
            - name: MYSQL_DATABASE
              value: "isucon"
            - name: MYSQL_USER
              value: "isucon"
            - name: MYSQL_PASSWORD
              value: "isucon"
          ports:
            - containerPort: 3306
              name: mysql
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          volumeMounts:
            - name: mysql-cnf
              mountPath: /etc/mysql/conf.d
            - name: mysql-initdb
              mountPath: /docker-entrypoint-initdb.d
            - name: mysql-logs
              mountPath: /var/log/mysql
          readinessProbe:
            exec:
              command: ["mysqladmin", "ping", "-h", "localhost", "-u", "isucon", "-pisucon"]
            initialDelaySeconds: 5
            periodSeconds: 3
      volumes:
        - name: mysql-cnf
          configMap:
            name: isucon-mysql-cnf
        - name: mysql-initdb
          configMap:
            name: isucon-mysql-initdb
        - name: mysql-logs
          emptyDir: {}
EOF

cat << 'EOF' > "$TARGET_DIR/manifests/mysql-service.yml"
apiVersion: v1
kind: Service
metadata:
  name: isucon-mysql
  namespace: isucon
spec:
  selector:
    app: isucon-mysql
  ports:
    - name: mysql
      port: 3306
      targetPort: 3306
EOF

# 4. manifests/nginx-configmap.yml, deployment, service
cat << 'EOF' > "$TARGET_DIR/manifests/nginx-configmap.yml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: isucon-nginx-conf
  namespace: isucon
data:
  nginx.conf: |
    user nginx;
    worker_processes auto;
    pid /var/run/nginx.pid;
    events { worker_connections 1024; }
    http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        log_format ltsv "time:$time_local\thost:$remote_addr\treq:$request\tstatus:$status\tmethod:$request_method\turi:$request_uri\tsize:$body_bytes_sent\tapptime:$upstream_response_time\treqtime:$request_time";
        access_log /var/log/nginx/access.log ltsv;
        error_log /var/log/nginx/error.log warn;
        sendfile on;
        keepalive_timeout 65;
        upstream app { server isucon-app:8000; keepalive 32; }
        server {
            listen 80;
            server_name _;
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

cat << 'EOF' > "$TARGET_DIR/manifests/nginx-deployment.yml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: isucon-nginx
  namespace: isucon
  labels:
    app: isucon-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: isucon-nginx
  template:
    metadata:
      labels:
        app: isucon-nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
              name: http
          resources:
            requests:
              cpu: "100m"
              memory: "64Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
          volumeMounts:
            - name: nginx-conf
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
            - name: nginx-logs
              mountPath: /var/log/nginx
          readinessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 3
      volumes:
        - name: nginx-conf
          configMap:
            name: isucon-nginx-conf
        - name: nginx-logs
          emptyDir: {}
EOF

cat << 'EOF' > "$TARGET_DIR/manifests/nginx-service.yml"
apiVersion: v1
kind: Service
metadata:
  name: isucon-nginx
  namespace: isucon
spec:
  selector:
    app: isucon-nginx
  ports:
    - name: http
      port: 80
      targetPort: 80
EOF

# 5. manifests/ingress.yml
cat << EOF > "$TARGET_DIR/manifests/ingress.yml"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: isucon-ingress
  namespace: isucon
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-cloudflare
spec:
  ingressClassName: "cloudflare-tunnel"
  rules:
    - host: ${APP_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: isucon-nginx
                port:
                  number: 80
EOF

# 6. manifests/benchmarker-configmap.yml
cat << 'EOF' > "$TARGET_DIR/manifests/benchmarker-configmap.yml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: isucon-benchmarker-script
  namespace: isucon
data:
  bench.sh: |
    #!/bin/sh
    set -e
    TARGET_URL="${1:-http://isucon-nginx.isucon.svc.cluster.local}"
    DURATION_SEC="${2:-10}"
    echo "🚀 ベンチマーク開始: ${TARGET_URL}"
    END_TIME=$(( $(date +%s) + DURATION_SEC ))
    TOTAL=0; OK=0; NG=0
    while [ $(date +%s) -lt $END_TIME ]; do
        curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/posts" > /dev/null && OK=$((OK+1)) || NG=$((NG+1))
        curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/posts/1" > /dev/null && OK=$((OK+1)) || NG=$((NG+1))
        curl -s -f --max-time 3 --connect-timeout 2 "${TARGET_URL}/api/heavy-calc" > /dev/null && OK=$((OK+1)) || NG=$((NG+1))
        TOTAL=$((TOTAL+3))
    done
    SCORE=$(( OK * 10 - NG * 50 ))
    echo "🏁 終了 | 総Req: ${TOTAL} | 成功: ${OK} | 失敗: ${NG} | スコア: ${SCORE}"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: isucon-benchmarker
  namespace: isucon
spec:
  ttlSecondsAfterFinished: 60
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: benchmarker
          image: curlimages/curl:latest
          command: ["/bin/sh", "/scripts/bench.sh", "http://isucon-nginx.isucon.svc.cluster.local", "10"]
          volumeMounts:
            - name: script
              mountPath: /scripts
      volumes:
        - name: script
          configMap:
            name: isucon-benchmarker-script
            defaultMode: 0755
EOF

# 7. argocd/app.yml
cat << EOF > "$TARGET_DIR/argocd/app.yml"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: isucon-dev
spec:
  project: default
  source:
    repoURL: 'https://github.com/AobaIwaki123/ai-workspace'
    targetRevision: HEAD
    path: $(basename "$TARGET_DIR")/manifests
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: isucon
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF

# 8. scripts/create-branch-infra.sh
cat << 'EOF' > "$TARGET_DIR/scripts/create-branch-infra.sh"
#!/usr/bin/env bash
set -euo pipefail
BRANCH="${1:-}"
if [ -z "$BRANCH" ]; then
    echo "Usage: $0 <branch-or-username>"
    exit 1
fi
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cp -r "${BASE_DIR}/manifests" "${BASE_DIR}/manifests-${BRANCH}"
cp -r "${BASE_DIR}/argocd" "${BASE_DIR}/argocd-${BRANCH}"
sed -i.bak "s/isucon\.aooba\.net/isucon-${BRANCH}\.aooba\.net/g" "${BASE_DIR}/manifests-${BRANCH}/ingress.yml" && rm -f "${BASE_DIR}/manifests-${BRANCH}/ingress.yml.bak"
sed -i.bak "s/name: isucon-dev/name: isucon-${BRANCH}/g" "${BASE_DIR}/argocd-${BRANCH}/app.yml" && rm -f "${BASE_DIR}/argocd-${BRANCH}/app.yml.bak"
echo "✓ Created manifests-${BRANCH} and argocd-${BRANCH}."
EOF
chmod +x "$TARGET_DIR/scripts/create-branch-infra.sh"

# 9. Makefile
cat << 'EOF' > "$TARGET_DIR/Makefile"
NAMESPACE := isucon
ALP_MATCH := "/api/posts/[0-9]+"

.PHONY: deploy delete bench alp slow pprof status

deploy:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k manifests/
	@kubectl rollout status deployment/isucon-mysql -n $(NAMESPACE) --timeout=60s || true
	@kubectl rollout status deployment/isucon-app -n $(NAMESPACE) --timeout=60s || true
	@kubectl rollout status deployment/isucon-nginx -n $(NAMESPACE) --timeout=60s || true

delete:
	kubectl delete -k manifests/

status:
	kubectl get pods,svc,ingress -n $(NAMESPACE)

bench:
	@kubectl delete job isucon-benchmarker -n $(NAMESPACE) --ignore-not-found=true > /dev/null
	@kubectl create -f manifests/benchmarker-configmap.yml -n $(NAMESPACE) || true
	@kubectl wait --for=condition=ready pod -l job-name=isucon-benchmarker -n $(NAMESPACE) --timeout=30s > /dev/null || true
	@kubectl logs -f job/isucon-benchmarker -n $(NAMESPACE)

alp:
	@NGINX_POD=$$(kubectl get pod -l app=isucon-nginx -n $(NAMESPACE) -o jsonpath="{.items[0].metadata.name}"); \
	kubectl exec $$NGINX_POD -n $(NAMESPACE) -c nginx -- cat /var/log/nginx/access.log | \
	docker run --rm -i tkuchiki/alp:latest ltsv --sort=sum -r -m $(ALP_MATCH)

slow:
	@MYSQL_POD=$$(kubectl get pod -l app=isucon-mysql -n $(NAMESPACE) -o jsonpath="{.items[0].metadata.name}"); \
	kubectl exec $$MYSQL_POD -n $(NAMESPACE) -c mysql -- cat /var/log/mysql/mysql-slow.log | \
	docker run --rm -i percona/percona-toolkit:latest pt-query-digest | head -n 45

pprof:
	@kubectl port-forward svc/isucon-app 6060:6060 -n $(NAMESPACE)
EOF

echo "✓ ISUCON Kubernetes Sandbox created at '$TARGET_DIR'!"
echo "💡 Deploy with: cd $TARGET_DIR && make deploy"
