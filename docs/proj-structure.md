# Go project structure

A reference for structuring Go projects, written for someone coming from C++/C#.

---

## 1. Module anatomy

A Go module is the unit of versioning and dependency management — equivalent to a `.csproj` / NuGet package or a CMake project with `vcpkg.json`. Every module has a `go.mod` at its root.

```
module github.com/username/myapp   ← the module path (used in all import statements)

go 1.26                            ← minimum Go version required

require (
    github.com/some/dep v1.2.3     ← direct dependencies
)

tool (
    github.com/golangci/golangci-lint/v2/cmd/golangci-lint  ← dev tools (Go 1.24+)
    golang.org/x/vuln/cmd/govulncheck
)
```

**Module path** is just a string — it doesn't have to be a real URL, but by convention it matches a VCS path so `go get` can find it. For private or local code, anything works (`example.com/myapp`, `myapp`).

`go.sum` is the lockfile with content hashes. Commit it, never edit it by hand.

---

## 2. The three project archetypes

### CLI tool

The simplest structure. One binary, no exposed API.

```
myapp/
├── cmd/
│   └── myapp/
│       └── main.go          ← entry point, parses flags, calls internal/cli
├── internal/
│   └── cli/
│       └── root.go          ← command logic
├── go.mod
├── go.sum
├── .golangci.yml
└── Makefile
```

### HTTP / gRPC service

A layered structure that separates concerns. This is what you show at a middle/senior interview.

```
myapp/
├── cmd/
│   └── server/
│       └── main.go          ← wires layers together, owns graceful shutdown
├── internal/
│   ├── config/
│   │   └── config.go        ← Config struct loaded from env
│   ├── handler/
│   │   └── handler.go       ← HTTP handlers; depends on Service interface
│   ├── service/
│   │   └── service.go       ← business logic; depends on Repository interface
│   ├── repository/
│   │   └── repository.go    ← database access; depends on *sql.DB
│   └── model/
│       └── model.go         ← shared domain types; no dependencies
├── migrations/
│   └── 001_init.sql
├── go.mod
├── go.sum
├── .golangci.yml
└── Makefile
```

### Library (reusable package)

No `cmd/`. The root directory IS the package. The module path is the import path.

```
mylib/
├── mylib.go             ← public API; package name matches directory name
├── mylib_test.go        ← black-box tests (package mylib_test)
├── example_test.go      ← Example* functions; appear as runnable docs on pkg.go.dev
├── internal/
│   └── ...              ← unexported helpers
├── go.mod
└── go.sum
```

---

## 3. Layered architecture in detail

This is the most important pattern for services. Each layer depends only on the layer below it through an **interface**, never a concrete type. Dependency direction is always downward.

```
cmd/main.go
    │
    ├── creates *repository.Repo (concrete)
    ├── creates *service.Service (concrete, receives repo as Repository interface)
    └── creates *handler.Handler (concrete, receives svc as Service interface)
```

**Why interfaces at each boundary?**

- Each layer defines the interface it needs from the layer below — not the other way around.
- This means `handler` doesn't import `service` or `repository` at all. It just declares an interface: "I need something that can do X."
- Constructors return concrete types (`*Repo`, `*Service`); only the consumer turns them into an interface. This is the "accept interfaces, return structs" rule.
- The concrete wiring happens only in `main.go`.
- Result: you can test `handler` with a mock service, and `service` with a mock repository, without touching a real database.

Analogy: similar to dependency injection in C# / Unity DI, but without a framework — Go does it with plain interfaces and constructor functions.

**Canonical package skeletons:**

`internal/model/model.go` — domain types, zero dependencies:
```go
package model

type Task struct {
    ID    string
    Title string
    Done  bool
}
```

`internal/repository/repository.go` — data access, returns a concrete type:
```go
package repository

import (
    "context"

    "<module>/internal/model"
)

// Repo returns a concrete type; consumers define the interface they need.
type Repo struct {
    // db *sql.DB
}

func New( /* db *sql.DB */ ) *Repo { return &Repo{} }

func (r *Repo) FindByID(ctx context.Context, id string) (*model.Task, error) {
    // query the database...
    return &model.Task{ID: id}, nil
}
```

`internal/service/service.go` — business logic, declares what it needs from the repo:
```go
package service

import (
    "context"

    "<module>/internal/model"
)

// Repository is the data access interface this service depends on.
// Defined here so service owns the contract, not the repository package.
type Repository interface {
    FindByID(ctx context.Context, id string) (*model.Task, error)
}

// Service holds business logic. New returns this concrete type.
type Service struct{ repo Repository }

func New(repo Repository) *Service { return &Service{repo: repo} }

func (s *Service) GetTask(ctx context.Context, id string) (*model.Task, error) {
    return s.repo.FindByID(ctx, id)
}
```

`internal/handler/handler.go` — HTTP layer, declares what it needs from the service:
```go
package handler

import (
    "context"
    "net/http"

    "<module>/internal/model"
)

// Service is the business logic interface this handler depends on.
type Service interface {
    GetTask(ctx context.Context, id string) (*model.Task, error)
}

type Handler struct{ svc Service }

func New(svc Service) *Handler { return &Handler{svc: svc} }

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
    mux.HandleFunc("GET /health", h.health)
    // mux.HandleFunc("GET /tasks/{id}", h.getTask)
}
```

`cmd/server/main.go` — the only place that knows about all concrete types:
```go
package main

import (
    "context"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "<module>/internal/config"
    "<module>/internal/handler"
    "<module>/internal/repository"
    "<module>/internal/service"
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
```

---

## 4. Package naming rules

- **Lowercase, one word, no underscores or mixedCase.** `handler`, `repository`, `config` — not `httpHandler`, `data_access`, `AppConfig`.
- **The package name is part of the API.** If the package is `config` and it exports `Config`, callers write `config.Config`. That's redundant — name the type `Config` and the package `config` and accept it, or rename the type to something cleaner like `App` or just export a `Load() Config` function.
- **Avoid generic names** like `util`, `common`, `helpers` — they become dumping grounds. Put code in the package that owns it.
- **Test files use `_test` suffix on the package name** for black-box tests: `package handler_test`. This forces you to test through the public API. Use `package handler` (no suffix) only for white-box tests that need unexported access.

---

## 5. The `internal/` package

`internal/` is enforced by the compiler: packages inside it can only be imported by code in the parent tree.

```
myapp/
├── internal/
│   └── service/       ← importable only from within myapp/
└── cmd/
    └── server/
        └── main.go    ← can import myapp/internal/service ✓

otherpkg/
└── main.go            ← cannot import myapp/internal/service ✗ (compile error)
```

Use `internal/` for everything that isn't a deliberate public API. For a service, that's almost everything. For a library, it's helper code that shouldn't be part of the contract.

Analogy: similar to `internal` access modifier in C#, but enforced at the module level.

---

## 6. `pkg/` — when and why

`pkg/` is an optional convention for code that is intended to be imported by external packages (the public SDK surface of a library or a framework). It's the opposite of `internal/`.

Most applications don't need `pkg/` at all. Use it only when you're deliberately publishing a reusable API alongside your binary. If you're writing a service, put everything in `internal/`.

---

## 7. Multiple binaries in one module

If a module produces multiple binaries, each gets its own subdirectory under `cmd/`:

```
myapp/
├── cmd/
│   ├── server/       ← go build ./cmd/server
│   ├── worker/       ← go build ./cmd/worker
│   └── migrate/      ← go build ./cmd/migrate
└── internal/
    └── ...           ← shared by all three binaries
```

Build a specific binary: `go build -o bin/server ./cmd/server`
Build all: `go build ./cmd/...`

---

## 8. Splitting into multiple modules

Stay in a single module until you have a concrete reason to split. Reasons to split:

- A library you want to version independently from the application.
- Teams that deploy different parts on different release cycles.
- Dramatically different dependency trees (a CLI tool vs. a heavy service).

Multiple modules in one repo use `go.work` (workspaces) so they can reference each other without publishing:

```
go.work
myapp/
    go.mod
mylib/
    go.mod
```

`go work init ./myapp ./mylib` — creates the workspace file, lets `myapp` import `mylib` locally.

---

## Quick reference

| Situation | Pattern |
|---|---|
| Single binary, no public API | `cmd/<name>/` + `internal/` |
| Multiple binaries, shared code | `cmd/<name1>/` + `cmd/<name2>/` + `internal/` |
| Reusable library | Root package + `internal/` for helpers |
| Public library + private app | `pkg/` for public API + `internal/` for app logic |
| Multiple independent modules | `go.work` workspace |
| Layered service | `handler → service interface → repository interface`, wired in `main.go` |
