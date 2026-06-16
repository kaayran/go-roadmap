# go-roadmap

Personal cheat-sheet and reference for learning Go, coming from a C++/C# gamedev background.

## Docs

- [syntax-and-features.md](docs/syntax-and-features.md) — Go syntax and language features explained for a C++/C# developer
- [dev-tooling.md](docs/dev-tooling.md) — development tools: what to install, what to use and when
- [pet-project-roadmap.md](docs/pet-project-roadmap.md) — project ideas by level, from warm-up to senior signal
- [proj-structure.md](docs/proj-structure.md) — module anatomy, project archetypes, layered architecture
- [vscode-rider-setup.md](docs/vscode-rider-setup.md) — make VS Code look and feel like JetBrains Rider (cross-OS)

## Tools

Shell scripts for common setup tasks:

| Script | What it does |
|---|---|
| `tools/install-go.bat` / `.sh` | Install Go + global tools on a new machine |
| `tools/new-project.bat` / `.sh` | Scaffold a new Go project (module, structure, linter, Makefile) |
| `tools/gen-structure.bat` / `.sh` | Generate layered project structure inside an existing module |
| `tools/gen-gitignore.bat` / `.sh` | Drop a Go-ready `.gitignore` into the current directory |
