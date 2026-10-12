#!/usr/bin/env bash
# ============================================================================
# ISUCON14 演習用EC2 起動スクリプト
#
# 起動後に公開IPを取得し、チームメンバーへ共有できるSSH Config更新用の
# 1行コマンドを表示する。SSH Configそのものは変更しない。
# ============================================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-1}"
INSTANCE_TAG_NAME="${ISUCON_INSTANCE_TAG_NAME:-isucon14-practice}"

die() {
  echo "エラー: $*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage:
  $0

Environment variables:
  AWS_REGION                  AWSリージョン (default: ap-northeast-1)
  ISUCON_INSTANCE_TAG_NAME   EC2のNameタグ (default: isucon14-practice)
USAGE
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
fi

command -v aws >/dev/null 2>&1 || die "aws コマンドが見つかりません。"

find_instance_id() {
  local instance_ids count

  instance_ids=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
      "Name=tag:Name,Values=${INSTANCE_TAG_NAME}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

  [[ "$instance_ids" == "None" ]] && instance_ids=""
  instance_ids=$(printf '%s\n' "$instance_ids" | tr '\t' '\n' | awk 'NF')
  count=$(printf '%s\n' "$instance_ids" | awk 'NF { count++ } END { print count + 0 }')

  if [[ "$count" -eq 0 ]]; then
    die "Nameタグ '${INSTANCE_TAG_NAME}' に一致するEC2インスタンスが見つかりません。"
  fi
  if [[ "$count" -ne 1 ]]; then
    die "Nameタグ '${INSTANCE_TAG_NAME}' に一致するEC2インスタンスが複数あります: $(printf '%s' "$instance_ids" | tr '\n' ' ')"
  fi

  printf '%s\n' "$instance_ids"
}

instance_state() {
  aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text
}

public_ip() {
  local ip
  ip=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  if [[ "$ip" == "None" || -z "$ip" ]]; then
    return 1
  fi
  printf '%s\n' "$ip"
}

print_ssh_config_command() {
  local ip="$1"

  echo
  echo "SSH Config更新コマンド（共有用・1行）:"
  printf '%s\n' "tmp=\$(mktemp ~/.ssh/config.XXXXXX) && awk -v ip='${ip}' 'BEGIN { target=0; found=0 } /^[[:space:]]*Host[[:space:]]/ { target=(\$0 ~ /(^|[[:space:]])isucon14([[:space:]]|\$)/ || \$0 ~ /(^|[[:space:]])isucon14-ubuntu([[:space:]]|\$)/) } target { found=1 } target && /^[[:space:]]*HostName[[:space:]]/ { \$0=\"    HostName \" ip } { print } END { if (!found) exit 2 }' ~/.ssh/config > \"\$tmp\" && chmod 600 \"\$tmp\" && mv \"\$tmp\" ~/.ssh/config"
  echo
  echo "接続確認: ssh isucon14"
}

print_hosts_command() {
  local ip="$1"

  echo
  echo "/etc/hosts更新コマンド（sudoなし・既存行を削除してから追記）:"
  printf '%s\n' "sed -i.bak '/[[:space:]]isuride\\.xiv\\.isucon\\.net[[:space:]]/d' /etc/hosts && printf '%s\\n' '${ip} isuride.xiv.isucon.net' >> /etc/hosts"
}

INSTANCE_ID=$(find_instance_id)
STATE=$(instance_state)
echo "対象: ${INSTANCE_ID} (${INSTANCE_TAG_NAME})"
echo "現在の状態: ${STATE}"

case "$STATE" in
  stopped)
    echo "EC2インスタンスを起動します..."
    aws ec2 start-instances \
      --region "$AWS_REGION" \
      --instance-ids "$INSTANCE_ID" \
      --output text \
      --query 'StartingInstances[0].{Id:InstanceId,State:CurrentState.Name}'
    ;;
  stopping)
    echo "停止処理の完了を待機します..."
    aws ec2 wait instance-stopped --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
    echo "EC2インスタンスを起動します..."
    aws ec2 start-instances \
      --region "$AWS_REGION" \
      --instance-ids "$INSTANCE_ID" \
      --output text \
      --query 'StartingInstances[0].{Id:InstanceId,State:CurrentState.Name}'
    ;;
  pending|running)
    echo "起動処理は不要です。"
    ;;
  *)
    die "起動対象として扱えない状態です: ${STATE}"
    ;;
esac

echo "running状態を待機します..."
aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
echo "AWSのステータスチェックを待機します..."
aws ec2 wait instance-status-ok --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"

IP=""
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if IP=$(public_ip); then
    break
  fi
  sleep 2
done

[[ -n "$IP" ]] || die "起動後の公開IPを取得できませんでした。"

echo
echo "起動完了"
echo "Instance ID: ${INSTANCE_ID}"
echo "Public IP:   ${IP}"
if command -v curl >/dev/null 2>&1; then
  HTTP_STATUS=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "http://${IP}/" || true)
  echo "HTTP status: ${HTTP_STATUS}"
fi
print_ssh_config_command "$IP"
print_hosts_command "$IP"
