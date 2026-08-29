#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# WSL Server: SSH Security Hardening Script (harden-ssh.sh)
# 
# 1. authorized_keys に公開鍵が存在するか検証（締め出し防止）
# 2. /etc/ssh/sshd_config.d/99-server-hardening.conf を配置
# 3. sshd -t で構文チェックして ssh サービスを再起動
# ==============================================================================

CONF_TARGET="/etc/ssh/sshd_config.d/99-server-hardening.conf"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
AUTH_KEYS="$TARGET_HOME/.ssh/authorized_keys"

if [[ $EUID -ne 0 ]]; then
    echo "エラー: sudo を付けて実行してください (例: sudo ./scripts/harden-ssh.sh)" >&2
    exit 1
fi

# --- 1. 公開鍵の存在確認 (締め出し防止) ---
if [[ ! -s "$AUTH_KEYS" ]]; then
    echo "エラー: $AUTH_KEYS に公開鍵が見つかりません。" >&2
    echo "先にクライアント端末から公開鍵を登録してください:" >&2
    echo "  ssh-copy-id $TARGET_USER@<WSLホストIP>" >&2
    exit 1
fi

echo "公開鍵を確認しました ($AUTH_KEYS)"

# --- 2. ドロップイン設定の配置 ---
mkdir -p /etc/ssh/sshd_config.d

cat << 'EOF' > "$CONF_TARGET"
# Hardened SSH Configuration for WSL Server
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF

# --- 3. 構文チェック & サービス再起動 ---
if ! sshd -t; then
    echo "エラー: sshd 構文チェックに失敗したため設定を破棄します。" >&2
    rm -f "$CONF_TARGET"
    exit 1
fi

systemctl restart ssh.service

echo "SSH セキュリティ強化が完了しました (パスワード認証無効化・公開鍵認証必須化)"
echo "※現在のセッションを維持したまま、別ターミナルから接続できることを確認してください。"
