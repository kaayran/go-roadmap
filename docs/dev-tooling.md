# go-tools.md — tooling for Go development

A guide for moving from C++/C# to Go. Where useful, an analogy to what you're used to is given.
Versions are current as of mid-2026: Go 1.26, golangci-lint v2.

The Go principle: most of what you need is already built into the `go` command. There are fewer third-party tools than in C++/C#, and the ecosystem is more uniform — almost everyone uses the same set.

---

## Recommended minimal set (where to start)

If you don't want to read the whole document — install this and move on:

- **Go toolchain** — the official installer from go.dev/dl
- **IDE:** GoLand (if you're used to JetBrains/Rider) or VS Code + the Go extension (free, the de facto standard)
- **gopls** — the official language server (installed automatically by the extension)
- **golangci-lint** — a meta-linter that bundles dozens of checks
- **Delve (dlv)** — the debugger
- **goimports** — formatting + auto-imports

Add the rest as needed.

---

## 1. Installing Go and managing versions

- **The official installer** (go.dev/dl) is the simplest path. Go can pull the required toolchain version itself via the `toolchain` line in go.mod.
- **Multiple project versions side by side:** the easiest way is through Go itself — you specify `go 1.26` in go.mod, and `go` downloads the required toolchain. For global switching there's `asdf` or `gvm`, but in most cases you don't need it.

Analogy: unlike C++ with its zoo of compilers and builds, here there's a single official toolchain, and the version is pinned in the project.

## 2. Editor / IDE

- **GoLand** (JetBrains) — if you're coming from Visual Studio / Rider, this will feel native: refactorings, debugger, test and profiler integration out of the box. Paid.
- **VS Code + the Go extension** — the free de facto standard. Internally it uses `gopls`, `dlv`, `gotests`, etc. Most Go developers live here.
- **Neovim / Helix + gopls** — for those who live in the terminal.

Whatever you choose, **gopls** runs under the hood — the official language server (autocomplete, go-to-definition, refactoring, inline errors). It's the "brain" behind IDE features; worth knowing about, because sometimes you need to restart or update it.

## 3. The built-in toolchain (the `go` command)

This is your main tool. Key subcommands:

- `go build` — build. Without `-o`, it just checks compilation.
- `go run` — build and run (for quick checks).
- `go test` — tests and benchmarks. Flags: `-race` (race detector, use constantly), `-cover` (coverage), `-bench`.
- `go vet` — the built-in static analyzer for suspicious constructs.
- `go mod` — dependency management (`tidy`, `download`, `why`, `graph`).
- `go work` — workspaces for multiple modules in one repository (monorepo).
- `go generate` — running code generators via `//go:generate` directives.
- `go tool` — running tool dependencies declared in go.mod (see section 10).
- `go doc` — package/symbol documentation right in the terminal.

Analogy: `go` replaces a combination of CMake/MSBuild + a package manager + part of your IDE's capabilities with a single command.

## 4. Formatting

Formatting in Go isn't up for debate — there's one canonical style, and arguments about braces and indentation simply don't exist.

- **gofmt** — built in, formats to the canon.
- **goimports** — the same, plus it automatically adds/removes imports. Set it as "format on save" in your IDE.

Analogy: like `clang-format`, but with a single, universally accepted config that nobody changes.

## 5. Linting

- **golangci-lint (v2)** — the main tool. It's a meta-linter: it runs dozens of analyzers in parallel and caches results. It includes `staticcheck`, `govet`, `errcheck`, `gosec`, and others. Configured via `.golangci.yml`. In CI this is a mandatory step.
  - In v2 the config structure changed: instead of `enable-all`/`disable-all`, there's now `linters.default` with values `all`/`standard`/`none`/`fast`. If you find an old config, there's a `golangci-lint migrate` command.
- **staticcheck** — a powerful standalone analyzer; it's included in golangci-lint anyway, so you usually don't need to install it separately.

A minimal `.golangci.yml` to start with:

```yaml
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
```

## 6. Debugging

- **Delve (dlv)** — the standard Go debugger. It's what GoLand and VS Code use under the hood for breakpoints, stepping, and inspecting variables and goroutines.
  - Useful: `dlv debug`, `dlv test`, and viewing all goroutines (`goroutines`) — indispensable when debugging concurrent code.
- For concurrency bugs, the main tool isn't a debugger but the **race detector**: `go test -race` and `go run -race`.

Analogy: Delve replaces gdb/lldb and the Visual Studio debugger.

## 7. Testing

The base framework (`testing`) is built in. On top of it:

- **testify** — assertions (`assert`/`require`) and suites. Removes the boilerplate of `if got != want { t.Errorf(...) }`.
- **google/go-cmp** — comparing complex structures with a human-readable diff (`cmp.Diff`).
- **gotestsum** — nicer, more readable test output, handy in CI.
- **mockgen** (uber/mock) or **mockery** — generating mocks from interfaces.
- **testcontainers-go** — spins up real dependencies (PostgreSQL, Redis, Kafka) in Docker straight from a test. The gold standard for integration tests.

Idiom: table-driven tests are the standard — worth getting used to right away.

## 8. Profiling and performance

This is where your performance background from C++ pays off directly.

- **pprof** — the built-in profiler: CPU, memory, blocking, goroutines. Hooks in with a couple of lines (`net/http/pprof`) or via test flags. Visualization: `go tool pprof`, including a flame graph in the browser.
- **go tool trace** — execution tracing: scheduler, goroutines, GC. Helps you see where concurrency stalls.
- **benchstat** — statistically sound comparison of benchmarks (before/after an optimization). Not "by eye," but accounting for variance.

## 9. Security and dependencies

- **govulncheck** — the official vulnerability scanner. It checks whether your code actually uses vulnerable spots in dependencies (not just the presence of a vulnerable version). Enable it in CI.
- **gosec** — static analysis for security issues (already included in golangci-lint).
- **trivy** — a vulnerability scanner for Docker images and dependencies.

## 10. Dependency and tool-dependency management

- **Go modules** — the built-in dependency manager. `go.mod` (the list) + `go.sum` (checksums). Commands: `go get`, `go mod tidy`.
- **Tool dependencies (Go 1.24+):** previously, tool versions were pinned via a hack — a `tools.go` file with blank imports. Now there's a proper `tool` directive in go.mod. You add it like this:

  ```bash
  go get -tool github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
  ```

  After that, the tool is run via `go tool golangci-lint run`, and its version is pinned for the whole team. This is the correct modern approach — everyone on the team uses the same tool versions.

Analogy: `go.mod` is like `*.csproj`/NuGet or `vcpkg.json`, but built into the language and without a separate manager.

## 11. Code generation

In Go, code generation is normal practice, not an exotic one.

- **sqlc** — generates type-safe Go code from plain SQL. Very popular for working with databases.
- **buf** (+ protoc-gen-go, protoc-gen-go-grpc) — modern tooling for Protocol Buffers and gRPC. `buf` is more convenient than raw `protoc`.
- **mockgen / mockery** — mocks for tests (see section 7).
- **stringer** — generates a `String()` method for enums.
- **ent** — an ORM/schema code generator from Meta, if you need a heavier data layer.

These are usually run via `//go:generate` + `go generate ./...`.

## 12. Hot reload (for web development)

- **air** — automatic rebuild and restart of a service when files change. Handy when developing HTTP/gRPC services so you don't restart by hand.

## 13. Task running (task runner)

To avoid memorizing long commands, projects are usually wrapped in tasks:

- **Make (Makefile)** — the most common, available everywhere.
- **Task (Taskfile.yml)** — a modern YAML alternative to Make, more readable.
- **mage** — a task runner where tasks are written in Go itself (if you dislike Makefile syntax).

A typical Makefile:

```makefile
.PHONY: test lint build run

test:
	go test -race -cover ./...

lint:
	go tool golangci-lint run

build:
	go build -o bin/app ./cmd/app

run:
	go run ./cmd/app
```

## 14. Containerization

- **Docker** + multi-stage build — the standard. You build the binary in one layer and place it in a minimal image in another.
- **Base image:** `scratch` (empty) or **distroless** — Go compiles into a static binary, so the image ends up tiny (a few MB) with a minimal attack surface.
- **ko** — builds and pushes images for Go services with no Dockerfile at all. Handy for Kubernetes.

A minimal multi-stage Dockerfile:

```dockerfile
FROM golang:1.26 AS build
WORKDIR /src
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app ./cmd/app

FROM gcr.io/distroless/static-debian12
COPY --from=build /app /app
ENTRYPOINT ["/app"]
```

## 15. CI/CD

- **GitHub Actions** — the most common choice for pet projects. A minimal pipeline: `build` + `test -race` + `golangci-lint` + `govulncheck`.
- **golangci-lint-action** and **setup-go** — the official actions, they simplify setup.

## 16. Pre-commit hooks

- **lefthook** — a fast git-hook manager that runs `gofmt`/`golangci-lint`/`go test` before a commit. An alternative is the `pre-commit` framework. Helps you avoid sending unformatted code to review.

## 17. Documentation

- **go doc** — documentation in the terminal.
- **pkgsite** — a local documentation server (the thing that runs on pkg.go.dev); you can stand it up for your own code.
- Documentation in Go is written as plain comments above exported symbols — there's no separate format like Doxygen/XML-doc.

---

## Summary: what you must know for an interview

The minimum expected from a middle/senior:

- Be fluent with the `go` command (build, test, mod, vet, generate).
- Constantly run `go test -race` and understand what it finds.
- Configure and read the output of `golangci-lint`.
- Debug with Delve, including inspecting goroutines.
- Capture and read a pprof profile (CPU/memory/goroutines).
- Write table-driven tests; understand mocks and integration tests with testcontainers.
- Build a service into a minimal Docker image (multi-stage + distroless/scratch).
- Have CI in the project with linting, tests, and govulncheck.

The good news: almost all of this is either built into `go` or installs with a single command, and the whole ecosystem uses the same set. After C++, that's a pleasant change.
