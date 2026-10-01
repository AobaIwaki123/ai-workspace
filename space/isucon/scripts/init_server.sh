#!/usr/bin/env bash
# ==========================================
# ISUCON サーバー初期セットアップスクリプト
# ==========================================
set -euo pipefail

echo "==> 1. 必要ツールのインストール..."
sudo apt-get update
sudo apt-get install -y htop dstat percona-toolkit git curl unzip

echo "==> 2. alp のインストール..."
ALP_VERSION="v1.0.21"
ALP_ARCH="linux_amd64" # ARM環境の場合は linux_arm64
if ! command -v alp &> /dev/null; then
    wget "https://github.com/tkuchiki/alp/releases/download/${ALP_VERSION}/alp_${ALP_ARCH}.zip" -O /tmp/alp.zip
    unzip /tmp/alp.zip -d /tmp/
    sudo install /tmp/alp /usr/local/bin/alp
    rm /tmp/alp.zip /tmp/alp
    echo "alp installed successfully!"
else
    echo "alp already installed."
fi

echo "==> 3. Git初期設定..."
git config --global user.name "isucon"
git config --global user.email "isucon@example.com"

echo "==> 4. 初期セットアップ完了！"
