#!/usr/bin/env bash
# ==============================================================================
# stacked-pr.sh - Helper script for managing Stacked Pull Requests
# Supports Git Worktrees, safe merging for protected branches, and instant stacking.
# ==============================================================================
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <command> [arguments]

Commands:
  create <child-branch> [parent-branch] [--worktree]
      Create a new stacked branch from a parent branch (defaults to current branch).
      If --worktree is specified, creates a worktree at .worktrees/<child-branch>.

  submit <child-branch> <parent-branch> "<title>" ["<body>"]
      Push the branch and create a GitHub Pull Request with <parent-branch> as base.

  stack-on <pr-number> <parent-branch>
      Convert an existing PR into a stacked PR on <parent-branch> (updates base branch & syncs).

  restack <child-branch> <parent-branch> [--merge]
      Sync parent branch into child branch. Defaults to rebase, falls back to merge if protected.

  update-base <pr-number> <new-base>
      Update the base branch of an existing GitHub PR (e.g. after parent is merged).

  list
      Display current branch and recent git branch tracking information.

Examples:
  $0 create feature/step-2 feature/step-1 --worktree
  $0 submit feature/step-2 feature/step-1 "feat: implement step 2"
  $0 stack-on 12 feature/step-1
  $0 restack feature/step-2 feature/step-1 --merge
  $0 update-base 12 main
EOF
}

cmd_create() {
  local child_branch="${1:-}"
  local parent_branch="${2:-}"
  local use_worktree=false

  if [[ -z "$child_branch" ]]; then
    echo "❌ Error: child branch name is required." >&2
    usage
    exit 1
  fi

  # Check if parent or 3rd arg is --worktree
  if [[ "$parent_branch" == "--worktree" ]]; then
    use_worktree=true
    parent_branch=""
  elif [[ "${3:-}" == "--worktree" ]]; then
    use_worktree=true
  fi

  if [[ -z "$parent_branch" ]]; then
    parent_branch="$(git rev-parse --abbrev-ref HEAD)"
  fi

  if [[ "$use_worktree" == true ]]; then
    local worktree_path=".worktrees/${child_branch}"
    echo "🥞 Creating stacked worktree '$worktree_path' (branch: $child_branch) from parent '$parent_branch'..."
    git worktree add "$worktree_path" -b "$child_branch" "$parent_branch"
    echo "✓ Successfully created stacked worktree at '$worktree_path'!"
  else
    echo "🥞 Creating stacked branch '$child_branch' from parent '$parent_branch'..."
    git checkout -b "$child_branch" "$parent_branch"
    echo "✓ Successfully created and checked out '$child_branch' (parent: $parent_branch)"
  fi
}

cmd_submit() {
  local child_branch="${1:-}"
  local parent_branch="${2:-}"
  local title="${3:-}"
  local body="${4:-}"

  if [[ -z "$child_branch" || -z "$parent_branch" || -z "$title" ]]; then
    echo "❌ Error: child-branch, parent-branch, and title are required." >&2
    usage
    exit 1
  fi

  if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI ('gh') is required for submitting PRs." >&2
    exit 1
  fi

  echo "🚀 Pushing '$child_branch' to origin..."
  git push -u origin "$child_branch"

  if [[ -z "$body" ]]; then
    body="## 🥞 Stacked PR
- **Base Branch (Parent)**: \`$parent_branch\`
- **Head Branch**: \`$child_branch\`

> [!NOTE]
> This is a stacked PR based on \`$parent_branch\`."
  fi

  echo "📝 Creating Pull Request via gh CLI with base '$parent_branch'..."
  gh pr create --base "$parent_branch" --head "$child_branch" --title "$title" --body "$body"
}

cmd_stack_on() {
  local pr_number="${1:-}"
  local parent_branch="${2:-}"

  if [[ -z "$pr_number" || -z "$parent_branch" ]]; then
    echo "❌ Error: pr-number and parent-branch are required." >&2
    usage
    exit 1
  fi

  if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI ('gh') is required." >&2
    exit 1
  fi

  echo "🥞 Converting PR #$pr_number into a Stacked PR based on '$parent_branch'..."
  
  # 1. Update Base Branch on GitHub
  echo "🔄 Updating Base Branch of PR #$pr_number to '$parent_branch' via gh CLI..."
  gh pr edit "$pr_number" --base "$parent_branch"

  echo "✓ Successfully stacked PR #$pr_number onto '$parent_branch'!"
}

cmd_restack() {
  local child_branch="${1:-}"
  local parent_branch="${2:-}"
  local mode="${3:-rebase}"

  if [[ -z "$child_branch" || -z "$parent_branch" ]]; then
    echo "❌ Error: child-branch and parent-branch are required." >&2
    usage
    exit 1
  fi

  echo "🔄 Fetching origin/$parent_branch..."
  git fetch origin "$parent_branch"

  if [[ "$mode" == "--merge" || "$mode" == "merge" ]]; then
    echo "🔄 Merging 'origin/$parent_branch' into '$child_branch' (Safe for protected branches)..."
    git merge "origin/$parent_branch" --no-edit
    echo "🚀 Pushing merged changes..."
    git push origin "$child_branch"
  else
    echo "🔄 Rebasing '$child_branch' onto 'origin/$parent_branch'..."
    if git rebase "origin/$parent_branch"; then
      echo "🚀 Pushing rebased '$child_branch'..."
      if ! git push --force-with-lease origin "$child_branch" 2>/dev/null; then
        echo "⚠️ Force-push rejected (branch protection enabled). Falling back to merge..."
        git rebase --abort 2>/dev/null || true
        git merge "origin/$parent_branch" --no-edit
        git push origin "$child_branch"
      fi
    else
      echo "❌ Rebase conflict detected. Please resolve conflicts or run with --merge." >&2
      exit 1
    fi
  fi
  echo "✓ Restack complete!"
}

cmd_update_base() {
  local pr_number="${1:-}"
  local new_base="${2:-main}"

  if [[ -z "$pr_number" ]]; then
    echo "❌ Error: pr-number is required." >&2
    usage
    exit 1
  fi

  if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI ('gh') is required." >&2
    exit 1
  fi

  echo "🔄 Updating Base Branch of PR #$pr_number to '$new_base'..."
  gh pr edit "$pr_number" --base "$new_base"
  echo "✓ PR #$pr_number base updated to '$new_base'."
}

cmd_list() {
  echo "🥞 Stacked PR Branch Status:"
  echo "--------------------------------------------------"
  echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"
  echo ""
  echo "Recent branches:"
  git log --graph --oneline --decorate -n 10
}

# --- Main Entrypoint ---
if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  create)
    cmd_create "$@"
    ;;
  submit)
    cmd_submit "$@"
    ;;
  stack-on)
    cmd_stack_on "$@"
    ;;
  restack)
    cmd_restack "$@"
    ;;
  update-base)
    cmd_update_base "$@"
    ;;
  list)
    cmd_list
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "❌ Error: Unknown command '$COMMAND'" >&2
    usage
    exit 1
    ;;
esac
