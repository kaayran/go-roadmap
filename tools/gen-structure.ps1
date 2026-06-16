param([string]$Type = "")

if (-not (Test-Path "go.mod")) {
    Write-Host "error: go.mod not found. run this from the root of a Go module."
    exit 1
}

$module = (Get-Content go.mod | Where-Object { $_ -match "^module " }) -replace "^module ", ""
$module = $module.Trim()
$appName = $module.Split("/")[-1]
# package identifiers cannot contain hyphens or other punctuation
$pkgName = ($appName -replace "[^a-zA-Z0-9]", "").ToLower()

$cmdEntry = Get-ChildItem -Path "cmd" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
$entryName = if ($cmdEntry) { $cmdEntry.Name } else { $appName }
$entryDir = "cmd\$entryName"

if (-not $Type) {
    Write-Host "project type:"
    Write-Host "  service  - HTTP service with layered architecture"
    Write-Host "  cli      - command-line tool"
    Write-Host "  library  - reusable Go package"
    Write-Host "  grpc     - gRPC service"
    Write-Host ""
    $Type = (Read-Host "type").Trim()
}

function New-File($path, $content) {
    $full = Join-Path (Get-Location).Path $path
    $dir = Split-Path $full
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force $dir | Out-Null
    }
    # normalize CRLF -> LF and guarantee exactly one trailing newline so files
    # are gofmt-clean; write UTF-8 without BOM
    $content = $content.Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($full, $content, $utf8)
    Write-Host "  $path"
}

function New-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Force $path | Out-Null
        Write-Host "  $path\"
    }
}

# ---------------------------------------------------------------------------
switch ($Type) {

# ---------------------------------------------------------------------------
"service" {
    Write-Host ""

    New-File "internal\model\model.go" @"
// Package model holds the domain types shared across layers.
package model

// Example is a placeholder domain type. Replace it with your own.
type Example struct {
	ID string
}
"@

    New-File "internal\repository\repository.go" @"
// Package repository provides data access.
package repository

import (
	"context"

	"$module/internal/model"
)

// Repo provides data access. Constructors return this concrete type;
// consumers depend on a narrow interface they define themselves.
type Repo struct {
	// db *sql.DB
}

// New returns a Repo.
func New() *Repo {
	return &Repo{}
}

// Get returns the Example with the given id.
func (r *Repo) Get(ctx context.Context, id string) (*model.Example, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return &model.Example{ID: id}, nil
}
"@

    New-File "internal\service\service.go" @"
// Package service holds the business logic.
package service

import (
	"context"

	"$module/internal/model"
)

// Repository is the data access contract this service depends on.
// Defined here so the service owns the interface it consumes.
type Repository interface {
	Get(ctx context.Context, id string) (*model.Example, error)
}

// Service holds business logic. Constructors return this concrete type.
type Service struct {
	repo Repository
}

// New returns a Service backed by the provided repository.
func New(repo Repository) *Service {
	return &Service{repo: repo}
}

// GetExample returns the Example with the given id.
func (s *Service) GetExample(ctx context.Context, id string) (*model.Example, error) {
	return s.repo.Get(ctx, id)
}
"@

    New-File "internal\handler\handler.go" @"
// Package handler holds the HTTP transport layer.
package handler

import (
	"context"
	"encoding/json"
	"net/http"

	"$module/internal/model"
)

// Service is the business logic contract this handler depends on.
// Defined here so the handler owns the interface it consumes.
type Service interface {
	GetExample(ctx context.Context, id string) (*model.Example, error)
}

// Handler holds HTTP route registrations.
type Handler struct {
	svc Service
}

// New returns a Handler wired to the provided service.
func New(svc Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes attaches all HTTP routes to mux.
func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /health", h.health)
	mux.HandleFunc("GET /example/{id}", h.getExample)
}

func (h *Handler) health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func (h *Handler) getExample(w http.ResponseWriter, r *http.Request) {
	ex, err := h.svc.GetExample(r.Context(), r.PathValue("id"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(ex); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}
"@

    New-File "internal\config\config.go" @"
// Package config loads runtime configuration from the environment.
package config

import "os"

// Config holds all runtime configuration loaded from environment variables.
type Config struct {
	Addr        string
	DatabaseURL string
}

// Load reads Config from environment variables, falling back to defaults.
func Load() Config {
	return Config{
		Addr:        getenv("ADDR", ":8080"),
		DatabaseURL: getenv("DATABASE_URL", ""),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
"@

    New-Dir "migrations"

    New-File "$entryDir\main.go" @"
// Command $entryName is the entry point.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"$module/internal/config"
	"$module/internal/handler"
	"$module/internal/repository"
	"$module/internal/service"
)

func main() {
	cfg := config.Load()

	repo := repository.New()
	svc := service.New(repo)
	h := handler.New(svc)

	mux := http.NewServeMux()
	h.RegisterRoutes(mux)

	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		slog.Info("server started", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "err", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info("shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("shutdown error", "err", err)
	}
}
"@
}

# ---------------------------------------------------------------------------
"cli" {
    Write-Host ""

    New-File "internal\cli\root.go" @"
// Package cli implements the command-line interface.
package cli

import (
	"flag"
	"fmt"
	"os"
)

// CLI is the root command runner.
type CLI struct{}

// New returns a ready-to-use CLI.
func New() *CLI { return &CLI{} }

// Run executes the CLI with the provided arguments and returns an exit code.
func (c *CLI) Run(args []string) int {
	fs := flag.NewFlagSet("$entryName", flag.ContinueOnError)
	verbose := fs.Bool("verbose", false, "verbose output")

	if err := fs.Parse(args); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return 1
	}

	if *verbose {
		fmt.Println("verbose mode on")
	}
	fmt.Println("hello!")
	return 0
}
"@

    New-File "$entryDir\main.go" @"
// Command $entryName is the entry point.
package main

import (
	"os"

	"$module/internal/cli"
)

func main() {
	os.Exit(cli.New().Run(os.Args[1:]))
}
"@
}

# ---------------------------------------------------------------------------
"library" {
    Write-Host ""

    if (Test-Path "cmd") {
        Write-Host "  note: libraries do not need a cmd/ directory. leaving it as-is."
    }

    # goimports requires an explicit alias when the package name differs from
    # the last path segment (e.g. a hyphenated module name)
    $imp = if ($pkgName -ne $appName) { "$pkgName `"$module`"" } else { "`"$module`"" }

    New-File "$appName.go" @"
// Package $pkgName is a reusable library. Replace this doc comment.
package $pkgName

// Version is the current library version.
const Version = "0.1.0"
"@

    New-File "${appName}_test.go" @"
package ${pkgName}_test

import (
	"testing"

	$imp
)

func TestVersion(t *testing.T) {
	if $pkgName.Version == "" {
		t.Fatal("Version must not be empty")
	}
}
"@

    New-File "example_test.go" @"
package ${pkgName}_test

import (
	"fmt"

	$imp
)

func ExampleVersion() {
	fmt.Println($pkgName.Version)
	// Output: 0.1.0
}
"@
}

# ---------------------------------------------------------------------------
"grpc" {
    Write-Host ""

    New-File "internal\config\config.go" @"
// Package config loads runtime configuration from the environment.
package config

import "os"

// Config holds all runtime configuration loaded from environment variables.
type Config struct {
	GRPCAddr string
}

// Load reads Config from environment variables, falling back to defaults.
func Load() Config {
	return Config{
		GRPCAddr: getenv("GRPC_ADDR", ":50051"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
"@

    New-Dir "proto"
    New-Dir "gen"
    New-File "proto\.gitkeep" ""

    New-File "$entryDir\main.go" @"
// Command $entryName is the entry point.
package main

import (
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	"google.golang.org/grpc"

	"$module/internal/config"
)

func main() {
	cfg := config.Load()

	lis, err := net.Listen("tcp", cfg.GRPCAddr)
	if err != nil {
		slog.Error("listen failed", "err", err)
		os.Exit(1)
	}

	srv := grpc.NewServer()
	// pb.RegisterMyServiceServer(srv, handler.New(...))

	go func() {
		slog.Info("grpc server started", "addr", cfg.GRPCAddr)
		if err := srv.Serve(lis); err != nil {
			slog.Error("serve error", "err", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info("shutting down...")
	srv.GracefulStop()
}
"@

    Write-Host ""
    Write-Host "  next: go get google.golang.org/grpc && go mod tidy"
    Write-Host "  then define your .proto files in proto/ and generate into gen/"
}

# ---------------------------------------------------------------------------
default {
    Write-Host "error: unknown type '$Type'. choose service, cli, library, or grpc."
    exit 1
}

} # end switch

Write-Host ""
Write-Host "done."
