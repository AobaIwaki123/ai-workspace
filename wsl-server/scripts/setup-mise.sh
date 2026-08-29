#!/usr/bin/env bash
# ==============================================================================
# setup-mise.sh
# mise (宣言的ツール・ランタイムマネージャー) の自動セットアップスクリプト
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MISE_TOML="$WORKSPACE_ROOT/mise.toml"

echo "=== [1/4] Installing mise CLI ==="
if ! command -v mise >/dev/null 2>&1 && [[ ! -f "$HOME/.local/bin/mise" ]]; then
    curl -fsSL https://mise.run | sh
else
    echo "mise is already installed."
fi

export PATH="$HOME/.local/bin:$PATH"

echo "=== [2/4] Configuring Shell Activation ==="
# Bash
if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'mise activate bash' "$HOME/.bashrc"; then
    echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> "$HOME/.bashrc"
    echo "Added mise activation to ~/.bashrc"
fi

# Zsh (存在する場合)
if [[ -f "$HOME/.zshrc" ]] && ! grep -q 'mise activate zsh' "$HOME/.zshrc"; then
    echo 'eval "$($HOME/.local/bin/mise activate zsh)"' >> "$HOME/.zshrc"
    echo "Added mise activation to ~/.zshrc"
fi

eval "$("$HOME/.local/bin/mise" activate bash)"

echo "=== [3/4] Linking global configuration ==="
mkdir -p "$HOME/.config/mise"
if [[ -f "$MISE_TOML" ]]; then
    cp "$MISE_TOML" "$HOME/.config/mise/config.toml"
    echo "Copied $MISE_TOML to ~/.config/mise/config.toml"
fi

echo "=== [4/5] Installing all tools declared in mise.toml ==="
mise install -y

echo "=== [5/5] Installing Antigravity CLI (agy) ==="
if ! command -v agy >/dev/null 2>&1 && [[ ! -f "$HOME/.local/bin/agy" ]]; then
    echo "Installing Antigravity CLI via official installer..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash
else
    echo "Antigravity CLI (agy) is already installed."
fi

echo ""
echo "=================================================="
echo "All tools setup completed successfully!"
echo "Installed mise tools summary:"
echo "--------------------------------------------------"
mise list
echo "--------------------------------------------------"
if command -v agy >/dev/null 2>&1 || [[ -f "$HOME/.local/bin/agy" ]]; then
    echo "Antigravity CLI: $(~/.local/bin/agy --version 2>/dev/null || echo 'installed')"
fi
echo "=================================================="
echo "To activate tools in your current terminal session, run:"
echo '  eval "$(~/.local/bin/mise activate bash)"'
echo "or restart your shell / SSH session."

