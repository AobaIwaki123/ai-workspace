#!/usr/bin/env bash
set -euo pipefail

echo "=== Verifying memo-cli ==="

echo "1. Formatting check..."
diff_files="$(gofmt -l .)"
if [[ -n "$diff_files" ]]; then
  echo "gofmt check failed on the following files:"
  echo "$diff_files"
  exit 1
fi

echo "2. Go vet..."
go vet ./...

echo "3. Go build..."
go build -o /dev/null ./cmd/memo

echo "4. Running smoke tests..."
go run ./cmd/memo list > /dev/null
go run ./cmd/memo path > /dev/null
go run ./cmd/memo decay -dry-run > /dev/null

echo "=== All memo-cli verifications passed successfully! ==="
