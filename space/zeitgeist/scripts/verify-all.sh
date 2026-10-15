#!/usr/bin/env bash
set -euo pipefail

echo "=== Verifying Zeitgeist CLI ==="

echo "1. Formatting check..."
test -z "$(gofmt -l .)"

echo "2. Go vet..."
go vet ./...

echo "3. Go build..."
go build -o /dev/null ./cmd/zeitgeist

echo "4. Running CLI smoke test with sample config..."
go run ./cmd/zeitgeist -config configs/sources.sample.yaml > /dev/null

echo "=== All Zeitgeist verifications passed successfully! ==="
