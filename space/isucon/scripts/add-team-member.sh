#!/usr/bin/env bash
# ==============================================================================
# ISUCON チームメンバー追加・アクセス権限付与スクリプト (ISUCON14対応)
# ==============================================================================
set -euo pipefail

DEFAULT_SG_ID="sg-07bf4071e40458bb5"
DEFAULT_REGION="ap-northeast-1"
DEFAULT_KEY_PATH="${HOME}/.ssh/isucon-key.pem"
TAG_NAME="${TARGET_TAG_NAME:-isucon14-practice}"

function usage() {
  cat << USAGE
Usage:
  $0 <github-username-or-publickey-file> [server-ip] [member-global-ip]

Arguments:
  1. github-username-or-publickey-file : GitHubアカウント名 (例: 'octocat') またはローカル公開鍵パス (例: '~/.ssh/id_ed25519.pub')
  2. server-ip                         : EC2のパブリックIP (省略時は自動検出または環境変数 TARGET_SERVER_IP)
  3. member-global-ip                  : メンバーの自宅・作業場所のグローバルIP (例: '198.51.100.1'。省略時はSG変更なし)

Examples:
  # GitHubアカウントから鍵を取得して登録
  $0 alice 35.79.226.184 203.0.113.10

  # 公開鍵ファイルを指定して登録
  $0 ~/.ssh/id_ed25519.pub 35.79.226.184
USAGE
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

IDENTIFIER="$1"
SERVER_IP="${2:-${TARGET_SERVER_IP:-}}"
MEMBER_IP="${3:-}"

# サーバーIPの取得（未指定の場合）
if [[ -z "$SERVER_IP" ]]; then
  echo "==> 稼働中の ${TAG_NAME} インスタンスからパブリックIPを取得中..."
  SERVER_IP=$(aws ec2 describe-instances \
    --region "$DEFAULT_REGION" \
    --filters "Name=tag:Name,Values=${TAG_NAME}" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text 2>/dev/null || true)
  if [[ -z "$SERVER_IP" || "$SERVER_IP" == "None" ]]; then
    echo "エラー: 稼働中のEC2インスタンスが見つかりませんでした。server-ip を直接指定してください。" >&2
    exit 1
  fi
fi

# 1. 公開鍵の取得
PUBKEYS=""
if [[ -f "$IDENTIFIER" ]]; then
  echo "==> 公開鍵ファイル '$IDENTIFIER' を読み込みます..."
  PUBKEYS=$(cat "$IDENTIFIER")
else
  echo "==> GitHub (https://github.com/${IDENTIFIER}.keys) から公開鍵を取得中..."
  PUBKEYS=$(curl -sSL "https://github.com/${IDENTIFIER}.keys")
  if [[ -z "$PUBKEYS" ]]; then
    echo "エラー: GitHubユーザー '${IDENTIFIER}' の公開鍵が見つかりませんでした。" >&2
    exit 1
  fi
fi

# 2. セキュリティグループへのIP許可（指定がある場合）
if [[ -n "$MEMBER_IP" ]]; then
  echo "==> セキュリティグループ (${DEFAULT_SG_ID}) にメンバーIP (${MEMBER_IP}/32) を追加中..."
  for port in 22 80 443 3000; do
    aws ec2 authorize-security-group-ingress \
      --region "$DEFAULT_REGION" \
      --group-id "$DEFAULT_SG_ID" \
      --protocol tcp \
      --port "$port" \
      --cidr "${MEMBER_IP}/32" 2>/dev/null || echo "  ※ Port ${port} は既に許可されているかスキップされました"
  done
  echo "  ✓ セキュリティグループ設定完了"
fi

# 3. サーバーへのSSH公開鍵登録
echo "==> サーバー (${SERVER_IP}) に公開鍵を登録中..."
SSH_OPTS=(-i "$DEFAULT_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

COMMAND=$(cat << 'EOF'
set -eu
NEW_KEYS=$(cat)
add_keys() {
  local target_user="$1"
  local auth_file="/home/${target_user}/.ssh/authorized_keys"
  if id "$target_user" &>/dev/null; then
    sudo mkdir -p "/home/${target_user}/.ssh"
    sudo touch "$auth_file"
    echo "$NEW_KEYS" | while IFS= read -r key; do
      if [[ -n "$key" ]] && ! sudo grep -Fq "$key" "$auth_file"; then
        echo "$key" | sudo tee -a "$auth_file" > /dev/null
      fi
    done
    sudo chown -R "${target_user}:${target_user}" "/home/${target_user}/.ssh"
    sudo chmod 700 "/home/${target_user}/.ssh"
    sudo chmod 600 "$auth_file"
    echo "  ✓ ${target_user} ユーザーに公開鍵を登録しました"
  fi
}
add_keys "ubuntu"
add_keys "isucon"
EOF
)

echo "$PUBKEYS" | ssh "${SSH_OPTS[@]}" "ubuntu@${SERVER_IP}" "bash -c '$(echo "$COMMAND")'"

echo ""
echo "=============================================================================="
echo "🎉 メンバーのセットアップが完了しました！ (ISUCON14 / ISURIDE)"
echo "=============================================================================="
echo "メンバーに以下の情報を共有してください:"
echo ""
echo "【SSH接続設定 (~/.ssh/config に追加)】"
cat << CONFIG
Host isucon14
    HostName ${SERVER_IP}
    User isucon
    Port 22
    ServerAliveInterval 60

Host isucon14-ubuntu
    HostName ${SERVER_IP}
    User ubuntu
    Port 22
    ServerAliveInterval 60
CONFIG
echo ""
echo "【接続確認コマンド】"
echo "  ssh isucon14"
echo ""
echo "【Web UI (ISURIDE) アクセス設定】"
echo "  手元の /etc/hosts に以下を追加するとブラウザで直接確認できます:"
echo "  ${SERVER_IP} isuride.xiv.isucon.net"
echo "  アクセスURL: https://isuride.xiv.isucon.net"
echo ""
echo "【ベンチマーク実行コマンド (isucon ユーザー)】"
echo "  ./bench run --addr 127.0.0.1:443 --target https://isuride.xiv.isucon.net --payment-url http://127.0.0.1:12346 --payment-bind-port 12346"
echo "=============================================================================="
