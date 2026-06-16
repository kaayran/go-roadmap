#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f "go.mod" ]]; then
    echo "error: go.mod not found. run this from the root of a Go module."
    exit 1
fi

MODULE=$(grep "^module " go.mod | awk '{print $2}')
APP_NAME="${MODULE##*/}"
# package identifiers cannot contain hyphens or other punctuation
PKG_NAME=$(printf '%s' "$APP_NAME" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')

# find an existing cmd/<name> entry dir; tolerate cmd/ being absent
ENTRY_DIR=$(find cmd -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1 || true)
if [[ -z "$ENTRY_DIR" ]]; then
    ENTRY_NAME="$APP_NAME"
    ENTRY_DIR="cmd/$APP_NAME"
else
    ENTRY_NAME=$(basename "$ENTRY_DIR")
fi

TYPE="${1:-}"
if [[ -z "$TYPE" ]]; then
    echo "project type:"
    echo "  service  - HTTP service with layered architecture"
    echo "  cli      - command-line tool"
    echo "  library  - reusable Go package"
    echo "  grpc     - gRPC service"
    echo ""
    read -rp "type: " TYPE
fi

new_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
    echo "  $path"
}

new_dir() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1"
        echo "  $1/"
    fi
}

echo ""

case "$TYPE" in

# ---------------------------------------------------------------------------
service)
    new_file "internal/model/model.go" \
"// Package model holds the domain types shared across layers.
package model

// Example is a placeholder domain type. Replace it with your own.
type Example struct {
	ID string
}"

    new_file "internal/repository/repository.go" \
"// Package repository provides data access.
package repository

import (
	\"context\"

	\"${MODULE}/internal/model\"
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
}"

    new_file "internal/service/service.go" \
"// Package service holds the business logic.
package service

import (
	\"context\"

	\"${MODULE}/internal/model\"
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
}"

    new_file "internal/handler/handler.go" \
"// Package handler holds the HTTP transport layer.
package handler

import (
	\"context\"
	\"encoding/json\"
	\"net/http\"

	\"${MODULE}/internal/model\"
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
	mux.HandleFunc(\"GET /health\", h.health)
	mux.HandleFunc(\"GET /example/{id}\", h.getExample)
}

func (h *Handler) health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func (h *Handler) getExample(w http.ResponseWriter, r *http.Request) {
	ex, err := h.svc.GetExample(r.Context(), r.PathValue(\"id\"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set(\"Content-Type\", \"application/json\")
	if err := json.NewEncoder(w).Encode(ex); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}"

    new_file "internal/config/config.go" \
"// Package config loads runtime configuration from the environment.
package config

import \"os\"

// Config holds all runtime configuration loaded from environment variables.
type Config struct {
	Addr        string
	DatabaseURL string
}

// Load reads Config from environment variables, falling back to defaults.
func Load() Config {
	return Config{
		Addr:        getenv(\"ADDR\", \":8080\"),
		DatabaseURL: getenv(\"DATABASE_URL\", \"\"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != \"\" {
		return v
	}
	return fallback
}"

    new_dir "migrations"

    new_file "$ENTRY_DIR/main.go" \
"// Command ${ENTRY_NAME} is the entry point.
package main

import (
	\"context\"
	\"log/slog\"
	\"net/http\"
	\"os\"
	\"os/signal\"
	\"syscall\"
	\"time\"

	\"${MODULE}/internal/config\"
	\"${MODULE}/internal/handler\"
	\"${MODULE}/internal/repository\"
	\"${MODULE}/internal/service\"
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
		slog.Info(\"server started\", \"addr\", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error(\"server error\", \"err\", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info(\"shutting down...\")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error(\"shutdown error\", \"err\", err)
	}
}"
    ;;

# ---------------------------------------------------------------------------
cli)
    new_file "internal/cli/root.go" \
"// Package cli implements the command-line interface.
package cli

import (
	\"flag\"
	\"fmt\"
	\"os\"
)

// CLI is the root command runner.
type CLI struct{}

// New returns a ready-to-use CLI.
func New() *CLI { return &CLI{} }

// Run executes the CLI with the provided arguments and returns an exit code.
func (c *CLI) Run(args []string) int {
	fs := flag.NewFlagSet(\"${ENTRY_NAME}\", flag.ContinueOnError)
	verbose := fs.Bool(\"verbose\", false, \"verbose output\")

	if err := fs.Parse(args); err != nil {
		fmt.Fprintf(os.Stderr, \"error: %v\n\", err)
		return 1
	}

	if *verbose {
		fmt.Println(\"verbose mode on\")
	}
	fmt.Println(\"hello!\")
	return 0
}"

    new_file "$ENTRY_DIR/main.go" \
"// Command ${ENTRY_NAME} is the entry point.
package main

import (
	\"os\"

	\"${MODULE}/internal/cli\"
)

func main() {
	os.Exit(cli.New().Run(os.Args[1:]))
}"
    ;;

# ---------------------------------------------------------------------------
library)
    if [[ -d "cmd" ]]; then
        echo "  note: libraries do not need a cmd/ directory. leaving it as-is."
    fi

    # goimports requires an explicit alias when the package name differs from
    # the last path segment (e.g. a hyphenated module name)
    if [[ "$PKG_NAME" != "$APP_NAME" ]]; then
        IMP="${PKG_NAME} \"${MODULE}\""
    else
        IMP="\"${MODULE}\""
    fi

    new_file "${APP_NAME}.go" \
"// Package ${PKG_NAME} is a reusable library. Replace this doc comment.
package ${PKG_NAME}

// Version is the current library version.
const Version = \"0.1.0\""

    new_file "${APP_NAME}_test.go" \
"package ${PKG_NAME}_test

import (
	\"testing\"

	${IMP}
)

func TestVersion(t *testing.T) {
	if ${PKG_NAME}.Version == \"\" {
		t.Fatal(\"Version must not be empty\")
	}
}"

    new_file "example_test.go" \
"package ${PKG_NAME}_test

import (
	\"fmt\"

	${IMP}
)

func ExampleVersion() {
	fmt.Println(${PKG_NAME}.Version)
	// Output: 0.1.0
}"
    ;;

# ---------------------------------------------------------------------------
grpc)
    new_file "internal/config/config.go" \
"// Package config loads runtime configuration from the environment.
package config

import \"os\"

// Config holds all runtime configuration loaded from environment variables.
type Config struct {
	GRPCAddr string
}

// Load reads Config from environment variables, falling back to defaults.
func Load() Config {
	return Config{
		GRPCAddr: getenv(\"GRPC_ADDR\", \":50051\"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != \"\" {
		return v
	}
	return fallback
}"

    new_dir "proto"
    new_dir "gen"
    new_file "proto/.gitkeep" ""

    new_file "$ENTRY_DIR/main.go" \
"// Command ${ENTRY_NAME} is the entry point.
package main

import (
	\"log/slog\"
	\"net\"
	\"os\"
	\"os/signal\"
	\"syscall\"

	\"google.golang.org/grpc\"

	\"${MODULE}/internal/config\"
)

func main() {
	cfg := config.Load()

	lis, err := net.Listen(\"tcp\", cfg.GRPCAddr)
	if err != nil {
		slog.Error(\"listen failed\", \"err\", err)
		os.Exit(1)
	}

	srv := grpc.NewServer()
	// pb.RegisterMyServiceServer(srv, handler.New(...))

	go func() {
		slog.Info(\"grpc server started\", \"addr\", cfg.GRPCAddr)
		if err := srv.Serve(lis); err != nil {
			slog.Error(\"serve error\", \"err\", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info(\"shutting down...\")
	srv.GracefulStop()
}"

    echo ""
    echo "  next: go get google.golang.org/grpc && go mod tidy"
    echo "  then define your .proto files in proto/ and generate into gen/"
    ;;

# ---------------------------------------------------------------------------
*)
    echo "error: unknown type '$TYPE'. choose service, cli, library, or grpc."
    exit 1
    ;;
esac

echo ""
echo "done."
