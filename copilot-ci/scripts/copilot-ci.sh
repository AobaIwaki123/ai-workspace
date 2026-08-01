#!/usr/bin/env bash
# copilot-ci.sh - GitHub CopilotをCIから呼び出すヘルパースクリプト

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  suggest <prompt>     - 一般的な提案を取得
  explain <file>       - ファイルのコードを説明
  review <file>        - コードレビューを実行
  test <file>          - テストケースを生成
  fix <file>           - バグ修正を提案
  commit               - コミットメッセージを生成
  pr-description       - PR説明を生成

Options:
  -t, --type TYPE      - ターゲットタイプ (shell, code, sql など)
  -r, --repo REPO      - リポジトリ (owner/name)
  -p, --pr NUMBER      - PR番号
  -h, --help           - このヘルプを表示

Examples:
  $0 suggest "How to optimize this SQL query?"
  $0 explain src/main.py
  $0 review src/api.ts --pr 42
  $0 commit
EOF
}

TYPE="shell"
REPO=""
PR_NUMBER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--type)
      TYPE="$2"
      shift 2
      ;;
    -r|--repo)
      REPO="$2"
      shift 2
      ;;
    -p|--pr)
      PR_NUMBER="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  suggest)
    PROMPT="${1:-}"
    if [[ -z "$PROMPT" ]]; then
      echo "Error: prompt required" >&2
      exit 1
    fi
    gh copilot suggest -t "$TYPE" "$PROMPT" ${REPO:+--repo "$REPO"} ${PR_NUMBER:+--pr "$PR_NUMBER"}
    ;;
  
  explain)
    FILE="${1:-}"
    if [[ -z "$FILE" ]] || [[ ! -f "$FILE" ]]; then
      echo "Error: valid file required" >&2
      exit 1
    fi
    gh copilot explain -t "$TYPE" "$(cat "$FILE")" ${REPO:+--repo "$REPO"} ${PR_NUMBER:+--pr "$PR_NUMBER"}
    ;;
  
  review)
    FILE="${1:-}"
    if [[ -z "$FILE" ]] || [[ ! -f "$FILE" ]]; then
      echo "Error: valid file required" >&2
      exit 1
    fi
    gh copilot suggest -t "$TYPE" "Review this code for bugs, security issues, and improvements: $(cat "$FILE")" ${REPO:+--repo "$REPO"} ${PR_NUMBER:+--pr "$PR_NUMBER"}
    ;;
  
  test)
    FILE="${1:-}"
    if [[ -z "$FILE" ]] || [[ ! -f "$FILE" ]]; then
      echo "Error: valid file required" >&2
      exit 1
    fi
    gh copilot suggest -t "$TYPE" "Generate comprehensive unit tests for this code: $(cat "$FILE")" ${REPO:+--repo "$REPO"} ${PR_NUMBER:+--pr "$PR_NUMBER"}
    ;;
  
  fix)
    FILE="${1:-}"
    if [[ -z "$FILE" ]] || [[ ! -f "$FILE" ]]; then
      echo "Error: valid file required" >&2
      exit 1
    fi
    gh copilot suggest -t "$TYPE" "Fix any bugs or issues in this code: $(cat "$FILE")" ${REPO:+--repo "$REPO"} ${PR_NUMBER:+--pr "$PR_NUMBER"}
    ;;
  
  commit)
    gh copilot suggest -t "$TYPE" "Generate a conventional commit message for these changes: $(git diff --cached --stat)" ${REPO:+--repo "$REPO"}
    ;;
  
  pr-description)
    BASE="${1:-origin/main}"
    DIFF=$(git diff "$BASE"...HEAD --stat)
    gh copilot suggest -t "$TYPE" "Write a PR description for these changes: $DIFF" ${REPO:+--repo "$REPO"} ${PR_NUMBER:+--pr "$PR_NUMBER"}
    ;;
  
  *)
    usage
    exit 1
    ;;
esac