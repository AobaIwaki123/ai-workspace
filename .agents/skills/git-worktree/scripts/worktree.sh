#!/usr/bin/env bash
# worktree.sh - Helper script for Git Worktree and shared directory management
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREES_DIR="$REPO_ROOT/.worktrees"
SHARED_DIR="$REPO_ROOT/.shared"

usage() {
  cat <<EOF
Usage: $0 <subcommand> [options]

Subcommands:
  create <branch-name> [base-branch]   Create a new worktree in .worktrees/<branch-name>
  list                                 List all active worktrees
  remove <branch-name>                 Remove a worktree and clean up
  sync-shared [worktree-path]          Link all files from .shared/ into the worktree
  prune                                Clean up stale worktree metadata
  -h, --help                           Show this help message

Examples:
  $0 create feature/login main
  $0 list
  $0 sync-shared .worktrees/feature/login
  $0 remove feature/login
EOF
}

sync_shared_files() {
  local target_dir="$1"
  if [[ -d "$SHARED_DIR" ]]; then
    mkdir -p "$target_dir"
    local count=0
    for file in "$SHARED_DIR"/*; do
      if [[ -f "$file" && "$(basename "$file")" != "README.md" ]]; then
        local filename="$(basename "$file")"
        ln -sf "$file" "$target_dir/$filename"
        count=$((count + 1))
      fi
    done
    if [[ $count -gt 0 ]]; then
      echo "✓ Linked $count shared file(s) from .shared/ to $target_dir"
    fi
  fi
}

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  create)
    BRANCH="${1:-}"
    BASE="${2:-main}"
    if [[ -z "$BRANCH" ]]; then
      echo "Error: Branch name is required." >&2
      usage
      exit 1
    fi

    # Clean branch name for directory path
    SANITIZED_PATH="$WORKTREES_DIR/$BRANCH"
    mkdir -p "$(dirname "$SANITIZED_PATH")"

    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
      echo "→ Checking out existing branch '$BRANCH' to $SANITIZED_PATH..."
      git worktree add "$SANITIZED_PATH" "$BRANCH"
    else
      echo "→ Creating new branch '$BRANCH' from '$BASE' in $SANITIZED_PATH..."
      git worktree add -b "$BRANCH" "$SANITIZED_PATH" "$BASE"
    fi

    # Sync shared files
    sync_shared_files "$SANITIZED_PATH"

    echo "🎉 Worktree created at: $SANITIZED_PATH"
    echo "💡 To start working in this worktree, navigate or open it with your editor."
    ;;

  list)
    echo "📋 Active Git Worktrees:"
    echo "--------------------------------------------------"
    git worktree list
    ;;

  remove)
    BRANCH="${1:-}"
    if [[ -z "$BRANCH" ]]; then
      echo "Error: Branch name or worktree path is required." >&2
      usage
      exit 1
    fi

    TARGET_PATH="$WORKTREES_DIR/$BRANCH"
    if [[ ! -d "$TARGET_PATH" && -d "$BRANCH" ]]; then
      TARGET_PATH="$BRANCH"
    fi

    if [[ -d "$TARGET_PATH" ]]; then
      echo "→ Removing worktree at $TARGET_PATH..."
      git worktree remove "$TARGET_PATH"
      git worktree prune
      echo "✓ Worktree removed successfully."
    else
      echo "Error: Worktree '$TARGET_PATH' not found." >&2
      exit 1
    fi
    ;;

  sync-shared)
    TARGET="${1:-.}"
    sync_shared_files "$TARGET"
    ;;

  prune)
    git worktree prune
    echo "✓ Pruned stale worktrees."
    ;;

  -h|--help|"")
    usage
    ;;

  *)
    echo "Error: Unknown subcommand '$COMMAND'" >&2
    usage
    exit 1
    ;;
esac
