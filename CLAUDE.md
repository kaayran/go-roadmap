# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal reference and tooling kit for learning Go (coming from a C++/C# gamedev background). It contains no Go source code — only documentation in `docs/` and setup scripts in `tools/`. There is nothing to build, test, or lint here.

## Language rule

All written content must be in English: documentation, script output messages, inline comments, file names. The user may communicate with the agent in any language.

## Scripts

Scripts come in pairs — `.bat` for Windows, `.sh` for Linux/macOS. When editing any script, both files must be kept in sync.

### new-project (.bat / .sh)

Interactive scaffolding for a new Go project. Prompts for project name, module path (e.g. `github.com/user/app`), and target directory. Creates:

- `cmd/<name>/main.go`
- `internal/`, `bin/` directories
- `go.mod` with `go mod init`
- `golangci-lint` and `govulncheck` pinned as tool dependencies via `go get -tool`
- `.golangci.yml` with a standard linter config
- `Makefile` with `test`, `lint`, `vuln`, `build`, `run` targets

### gen-structure (.bat / .ps1 / .sh)

Generates a layered directory structure and stub Go files inside an **existing** Go module (must be run from the module root where `go.mod` lives). Reads the module path from `go.mod` to fill import paths automatically.

Accepts an optional positional argument for non-interactive use: `gen-structure.bat service`

Supported types:

- **service** — creates `internal/{config,model,handler,service,repository}/`, `migrations/`, and rewrites `cmd/<name>/main.go` with a fully wired HTTP server + graceful shutdown.
- **cli** — creates `internal/cli/root.go` with a `flag`-based runner and updates `main.go`.
- **library** — creates a root package file, a black-box test file, and an `example_test.go` for godoc.
- **grpc** — same as service but with `proto/`, `gen/`, and a gRPC server main instead of HTTP.

Windows uses a `.ps1` script for logic; `.bat` is a thin wrapper calling it via `powershell -ExecutionPolicy Bypass`.

**Invariant when editing the templates:** every generated `service`/`cli`/`library` scaffold must stay `gofmt`-clean, `go build`-clean, and pass the shipped `.golangci.yml` (errcheck, govet, staticcheck, revive, gosec) with zero issues. The `grpc` scaffold is the one exception — it needs `go get google.golang.org/grpc` first. Gotchas already handled, do not regress them: the `.ps1` writer must emit UTF-8 **without BOM** and a trailing newline (Windows PowerShell 5.1 has no `UTF8NoBOM` encoding value); package identifiers must be sanitized of hyphens (`my-lib` → `mylib`) and library test imports aliased when the last path segment differs from the package name; main packages need a `// Command <name> ...` doc comment; `http.Server` needs `ReadHeaderTimeout` (gosec G112).

### gen-gitignore (.bat / .sh)

Copies `tools/gitignore.template` into the current working directory as `.gitignore`. Asks before overwriting. To change what goes into generated gitignores, edit the template — not the script.

### install-go (.bat / .sh)

Installs Go and five global tools (`gopls`, `goimports`, `dlv`, `golangci-lint`, `govulncheck`). Platform behavior:
- **Windows**: uses `winget install GoLang.Go`
- **macOS**: uses `brew install go` (installs Homebrew first if missing)
- **Linux**: fetches the current version from `go.dev/VERSION`, downloads the right tarball for the detected arch, extracts to `/usr/local/go`, and appends to `PATH` in `.bashrc` or `.zshrc`

## Key design decisions

**Global vs. per-project tools.** `gopls`, `goimports`, and `dlv` are global-only (IDE tooling). `golangci-lint` and `govulncheck` should also be pinned per-project via `go get -tool` so the whole team uses the same versions — `new-project` does this automatically.

**Script output style.** Scripts are intentionally minimalist: no ASCII banners, no step counters, short prompts. Keep new scripts in the same style.

**gitignore template.** `tools/gitignore.template` is the single source of truth for gitignore content. It has sections for Go, IDEs, AI agents, OS, and secrets. AI agent sections include commented-out negation patterns (e.g. `# !.cursor/rules`) for teams that want to track project-level configs.
