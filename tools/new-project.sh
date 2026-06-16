#!/usr/bin/env bash
set -euo pipefail

read -rp "name: " PROJECT_NAME
[[ -z "$PROJECT_NAME" ]] && echo "error: project name is required" && exit 1

read -rp "module (e.g. github.com/username/myapp): " MODULE_PATH
[[ -z "$MODULE_PATH" ]] && echo "error: module path is required" && exit 1

read -rp "location (default: ~/projects): " BASE_DIR
BASE_DIR="${BASE_DIR:-$HOME/projects}"

PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"

echo ""
echo "  $PROJECT_DIR  ($MODULE_PATH)"
echo ""
read -rp "create? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "cancelled." && exit 0
echo ""

mkdir -p "$PROJECT_DIR/cmd/$PROJECT_NAME"
mkdir -p "$PROJECT_DIR/internal"
mkdir -p "$PROJECT_DIR/bin"

cat > "$PROJECT_DIR/cmd/$PROJECT_NAME/main.go" <<EOF
package main

import "fmt"

func main() {
	fmt.Println("Hello, $PROJECT_NAME!")
}
EOF

cd "$PROJECT_DIR"
go mod init "$MODULE_PATH"

echo "pinning tools..."
go get -tool github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go get -tool golang.org/x/vuln/cmd/govulncheck@latest
go mod tidy

cat > "$PROJECT_DIR/.golangci.yml" <<'EOF'
version: "2"
linters:
  default: standard
  enable:
    - errcheck
    - govet
    - staticcheck
    - revive
    - gosec
formatters:
  enable:
    - gofmt
    - goimports
EOF

cat > "$PROJECT_DIR/Makefile" <<EOF
.PHONY: test lint build run vuln

test:
	go test -race -cover ./...

lint:
	go tool golangci-lint run

vuln:
	go tool govulncheck ./...

build:
	go build -o bin/$PROJECT_NAME ./cmd/$PROJECT_NAME

run:
	go run ./cmd/$PROJECT_NAME
EOF

echo ""
echo "done: $PROJECT_DIR"
echo ""
echo "  cd $PROJECT_DIR"
echo "  go run ./cmd/$PROJECT_NAME"
