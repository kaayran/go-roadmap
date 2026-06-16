@echo off
setlocal EnableDelayedExpansion

set /p PROJECT_NAME=name:
if "!PROJECT_NAME!"=="" ( echo error: project name is required & exit /b 1 )

set /p MODULE_PATH=module (e.g. github.com/username/myapp):
if "!MODULE_PATH!"=="" ( echo error: module path is required & exit /b 1 )

set /p BASE_DIR=location (default: C:\Projects):
if "!BASE_DIR!"=="" set BASE_DIR=C:\Projects

set PROJECT_DIR=!BASE_DIR!\!PROJECT_NAME!

echo.
echo   !PROJECT_DIR!  ^(!MODULE_PATH!^)
echo.
set /p CONFIRM=create? (y/n):
if /i not "!CONFIRM!"=="y" ( echo cancelled. & exit /b 0 )
echo.

mkdir "!PROJECT_DIR!\cmd\!PROJECT_NAME!" 2>nul
mkdir "!PROJECT_DIR!\internal" 2>nul
mkdir "!PROJECT_DIR!\bin" 2>nul

(
echo package main
echo.
echo import "fmt"
echo.
echo func main^(^) {
echo 	fmt.Println^("Hello, !PROJECT_NAME!!"^)
echo }
) > "!PROJECT_DIR!\cmd\!PROJECT_NAME!\main.go"

pushd "!PROJECT_DIR!"
go mod init !MODULE_PATH!
if errorlevel 1 ( echo error: go mod init failed & popd & exit /b 1 )

echo pinning tools...
go get -tool github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go get -tool golang.org/x/vuln/cmd/govulncheck@latest
go mod tidy
popd

(
echo version: "2"
echo linters:
echo   default: standard
echo   enable:
echo     - errcheck
echo     - govet
echo     - staticcheck
echo     - revive
echo     - gosec
echo formatters:
echo   enable:
echo     - gofmt
echo     - goimports
) > "!PROJECT_DIR!\.golangci.yml"

(
echo .PHONY: test lint build run vuln
echo.
echo test:
echo 	go test -race -cover ./...
echo.
echo lint:
echo 	go tool golangci-lint run
echo.
echo vuln:
echo 	go tool govulncheck ./...
echo.
echo build:
echo 	go build -o bin/!PROJECT_NAME! ./cmd/!PROJECT_NAME!
echo.
echo run:
echo 	go run ./cmd/!PROJECT_NAME!
) > "!PROJECT_DIR!\Makefile"

echo.
echo done: !PROJECT_DIR!
echo.
echo   cd !PROJECT_DIR!
echo   go run ./cmd/!PROJECT_NAME!

endlocal
