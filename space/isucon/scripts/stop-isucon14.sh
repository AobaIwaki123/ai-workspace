#!/usr/bin/env bash
# ============================================================================
# ISUCON14 演習用EC2 停止スクリプト
#
# EC2を停止し、起動時の課金を止める。EBS上のデータは保持されるが、
# 通常の公開IPは解放されるため、次回起動時にIPが変わる。
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

INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Name,Values=${INSTANCE_TAG_NAME}" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)
[[ "$INSTANCE_IDS" == "None" ]] && INSTANCE_IDS=""
INSTANCE_IDS=$(printf '%s\n' "$INSTANCE_IDS" | tr '\t' '\n' | awk 'NF')
INSTANCE_COUNT=$(printf '%s\n' "$INSTANCE_IDS" | awk 'NF { count++ } END { print count + 0 }')

if [[ "$INSTANCE_COUNT" -eq 0 ]]; then
  die "Nameタグ '${INSTANCE_TAG_NAME}' に一致するEC2インスタンスが見つかりません。"
fi
if [[ "$INSTANCE_COUNT" -ne 1 ]]; then
  die "Nameタグ '${INSTANCE_TAG_NAME}' に一致するEC2インスタンスが複数あります: $(printf '%s' "$INSTANCE_IDS" | tr '\n' ' ')"
fi

INSTANCE_ID="$INSTANCE_IDS"
STATE=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)

echo "対象: ${INSTANCE_ID} (${INSTANCE_TAG_NAME})"
echo "現在の状態: ${STATE}"

case "$STATE" in
  stopped)
    echo "すでに停止しています。"
    ;;
  stopping)
    echo "停止処理の完了を待機します..."
    ;;
  pending)
    echo "起動処理の完了を待機してから停止します..."
    aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
    ;;
  running)
    echo "EC2インスタンスを停止します..."
    aws ec2 stop-instances \
      --region "$AWS_REGION" \
      --instance-ids "$INSTANCE_ID" \
      --output text \
      --query 'StoppingInstances[0].{Id:InstanceId,State:CurrentState.Name}'
    ;;
  *)
    die "停止対象として扱えない状態です: ${STATE}"
    ;;
esac

if [[ "$STATE" != "stopped" ]]; then
  aws ec2 wait instance-stopped --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
fi

echo "停止完了: ${INSTANCE_ID}"
echo "次回起動時は公開IPが変わるため、start-isucon14.sh が表示するSSH Config更新コマンドを実行してください。"
