# go-pet-roadmap.md — pet project ideas for learning Go

A roadmap for the path "C++/C# (gamedev) → middle/senior Go".
Projects are grouped into 4 levels. The purpose of each level:

- **Level 1 — Warm-up.** Get used to the syntax, stdlib, and tooling. Days.
- **Level 2 — Idioms and concurrency.** The core of a Go interview. About a week per project.
- **Level 3 — Production-grade services.** What you show in an interview to prove "I can write a backend." 1–3 weeks.
- **Level 4 — Senior signal.** Distributed and high-load systems. One polished project is enough. Multi-week.
- **Level 5 — External API integrations.** A cross-cutting category covering resilience against third-party systems.

Core principle: 2–3 polished projects (tests, README, clean structure, Docker, CI) beat 10 abandoned ones. One project must be a concentrated demonstration of concurrency — that's what candidates get filtered on.

Each project lists: Go concepts, key stack, and stretch goals. Projects marked "gamedev fit" lean on your background.

---

## Level 1 — Warm-up (syntax, stdlib, tooling)

### 1.1. CLI calculator / unit converter
Argument parsing, errors as values, output formatting.
- Concepts: basic syntax, `error`, `fmt`, package structure
- Stack: stdlib `flag` or `cobra`
- Stretch: REPL mode, calculation history

### 1.2. `wc` / `grep` lite utility
A classic clone of a Unix tool. Reading files and stdin, flags.
- Concepts: `bufio`, `io.Reader`/`io.Writer`, working with streams
- Stretch: parallel processing of multiple files (a bridge to Level 2)

### 1.3. Markdown → HTML converter
A simple line-by-line parser, no third-party libraries.
- Concepts: strings, `strings`/`regexp`, structs
- Stretch: support for nested lists, tables

### 1.4. JSON formatter / schema validator
Reads JSON, validates against a simple schema, prints with indentation.
- Concepts: `encoding/json`, working with `map[string]any` and struct tags
- Stretch: custom `MarshalJSON`/`UnmarshalJSON`

### 1.5. Password generator / TOTP generator
Small, but touches crypto.
- Concepts: `crypto/rand`, `crypto/hmac`, encodings
- Stretch: compatibility with Google Authenticator (RFC 6238)

---

## Level 2 — Idioms and concurrency (the core of the interview)

### 2.1. Concurrent web crawler (recommended)
Crawls a site across N goroutines, with depth and worker-count limits, and URL deduplication.
- Concepts: goroutines, channels, `sync.WaitGroup`, worker pool, `context` for cancellation
- Stack: `net/http`, `golang.org/x/net/html`
- Stretch: rate limiting, graceful shutdown on Ctrl+C, a pprof report on goroutine leaks
- Why it matters: the canonical "show me you understand concurrency" task. Make sure `go test -race` is clean.

### 2.2. Concurrent rate limiter
A thread-safe token bucket / leaky bucket implementation.
- Concepts: `sync.Mutex` vs channels, `atomic`, timing
- Stretch: a distributed variant backed by Redis

### 2.3. In-memory key-value store with TTL
Your own mini-Redis: GET/SET/DEL, key expiration, thread safety.
- Concepts: `sync.RWMutex`, background eviction goroutines, generics
- Stretch: LRU eviction, a simple protocol over TCP (`net`)

### 2.4. Job queue / worker pool library
A task queue with priorities, retries, and concurrent workers.
- Concepts: channels, `select`, `context`, backpressure, graceful drain
- Stretch: task persistence, dead-letter queue

### 2.5. Data processing pipeline
Fan-out/fan-in: read a stream, process it through stages in parallel, collect the result.
- Concepts: the pipeline pattern, cancellation via `context`, error handling within the pipeline
- Gamedev fit: as a stage — processing telemetry or player events
- Stretch: benchmarks across parallelism levels, profiling

### 2.6. Real-time WebSocket chat server (gamedev fit)
Rooms, message broadcast, client connect and disconnect.
- Concepts: a goroutine per connection, the hub pattern via channels, races during broadcast
- Stack: `gorilla/websocket` or `nhooyr.io/websocket`
- Stretch: message history, presence, typed events

---

## Level 3 — Production-grade services (backend maturity)

### 3.1. A "grown-up" REST API with PostgreSQL (recommended)
A CRUD service (e.g., a task tracker or catalog), but with the emphasis on engineering maturity rather than features.
- Concepts: layered architecture (handler → service → repository), DI, idiomatic error handling
- Stack: chi/gin, PostgreSQL, `sqlc` or `pgx`, migrations (golang-migrate/goose), `slog`
- Stack: Docker + docker-compose, Makefile, config via env
- Tests: table-driven, integration tests with testcontainers, CI (GitHub Actions)
- Stretch: graceful shutdown, health checks, middleware (auth, request-id, logging, recovery)
- Why it matters: proof that you write maintainable backends. Structure and tests matter more than the domain here.

### 3.2. gRPC microservice + protobuf
The same domain, but with an inter-service protocol.
- Concepts: gRPC, streaming RPC, interceptors (the middleware analog)
- Stack: protobuf, `buf` for generation, gRPC-gateway for a REST facade
- Stretch: mTLS between services, reflection, the health-checking protocol

### 3.3. URL shortener with metrics
A classic, but with the full observability harness.
- Concepts: cache (Redis) + DB, hit/miss logic
- Stack: Prometheus metrics, OpenTelemetry tracing, a Grafana dashboard
- Stretch: load testing (k6/vegeta) and optimization driven by pprof

### 3.4. Authentication service (JWT/OAuth)
Registration, login, refresh tokens, authorization middleware.
- Concepts: security (bcrypt/argon2), sessions, RBAC
- Stretch: OAuth2 providers, brute-force rate limiting, audit log

### 3.5. File storage / image processing service
File upload, background thumbnail generation, serving via a CDN-like layer.
- Concepts: streaming large files, background workers, `context` deadlines
- Stack: S3-compatible storage (MinIO), a task queue
- Stretch: parallel image processing with a CPU limit

---

## Level 4 — Senior signal (distributed and high-load)

One such project, finished and well-documented, is enough. This is the centerpiece of the portfolio.

### 4.1. Multiplayer backend: matchmaking + game state (main one, gamedev fit)
Your key project given your background. Players join a queue, the matchmaker assembles a lobby by rating/region, a game session spins up, and state syncs in real time.
- Concepts: intense concurrency — goroutines per session/player, channels, `context`, cancellation, races, leaks
- Concepts: actor-like entities, simulation ticks, event queues
- Stack: WebSocket/gRPC streaming, Redis for the matchmaking queue and presence
- Stretch: an authoritative server with a fixed tick rate, lag compensation, horizontal scaling of sessions
- Why it's a senior signal: it simultaneously shows domain expertise, real-time load, and the hardest part of Go (concurrency under load). You can talk about a project like this for an hour in an interview.

### 4.2. Real-time leaderboard with millions of entries (gamedev fit)
Ingest results, recompute ranks instantly, serve the top and a player's "neighbors."
- Concepts: concurrent updates, consistency, sharding
- Stack: Redis sorted sets, write batching, cache invalidation
- Stretch: geo-distribution, protection against cheater spikes, backup to PostgreSQL

### 4.3. Distributed job scheduler (your own mini-Temporal)
Scheduling and reliable execution of tasks on a schedule with guarantees.
- Concepts: leader election, idempotency, at-least-once semantics
- Stack: etcd/Redis for coordination, a queue, retries with backoff
- Stretch: cron expressions, execution observability, recovery after crashes

### 4.4. Event-driven system on Kafka/NATS
Several services communicating via events (e.g., order → payment → delivery).
- Concepts: eventual consistency, the outbox pattern, sagas, duplicate handling
- Stack: Kafka or NATS JetStream, multiple Go services, protobuf events
- Stretch: end-to-end tracing (OpenTelemetry), DLQ, event replay

### 4.5. Your own mini-Raft / distributed KV store
The hardcore option: consensus and replication.
- Concepts: Raft (leader election, log replication), networking, fault tolerance
- Stack: gRPC between nodes, a persistent log
- Stretch: snapshots, dynamic cluster membership; implement from scratch following the Raft paper
- Why: if you pull it off, it's an instant senior+ conversation about distributed systems.

### 4.6. API gateway / reverse proxy
Routing, load balancing, rate limiting, auth at the cluster edge.
- Concepts: `net/http/httputil` reverse proxy, middleware chains, concurrency limits
- Stretch: circuit breaker, service discovery, dynamic configuration without restarts

---

## Level 5 — External API integrations (cross-cutting category)

This category is broken out separately because working with third-party APIs is a skill of its own that interviewers value: OAuth2 flows, resilience to other people's failures (retries, exponential backoff, circuit breaker), deadlines and cancellation via `context`, pagination, request limits, safe secret storage, idempotency. Projects within it go from simple to complex.

Common concepts for the whole category: a custom `http.Client` with timeouts, `context` for outbound-call deadlines, handling errors and response codes, retries with jitter, response caching, config and secrets via env, and sometimes receiving webhooks.

### 5.1. Weather / currency aggregator (an easy start)
Pulls data from open APIs (OpenWeather, exchange rate, CoinGecko) and serves a summary.
- Concepts: REST client, JSON parsing, response cache with TTL, API keys via env
- Stack: stdlib `net/http`, optionally Redis for the cache
- Stretch: aggregating several sources in parallel (goroutines) with a deadline for the whole request

### 5.2. Telegram / Discord bot
A bot that reacts to commands: reminders, polls, a chat duty officer. Discord is especially close to the gamedev community.
- Concepts: long polling or webhooks, handling updates in goroutines, per-user state
- Stack: `go-telegram-bot-api` or `discordgo`
- Stretch: slash commands, a background task queue, persistence in a DB
- Gamedev fit: a bot for a gaming guild — server status, match scheduling, integration with a game API

### 5.3. GitHub tool (stats / automation)
A CLI or service: gathers repository stats, automates routine work (labels, releases, PR reports).
- Concepts: pagination, GitHub rate limiting (X-RateLimit headers), GraphQL vs REST
- Stack: `google/go-github`, OAuth/personal access token
- Stretch: reacting to GitHub webhooks, a team activity dashboard

### 5.4. Google Sheets as a reporting backend
A service that dumps data (metrics, requests, logs) into a Google Sheet and reads it back — "a database for non-programmers."
- Concepts: OAuth2 service account, write batching, mapping rows to structs
- Stack: `google.golang.org/api/sheets/v4`, `golang.org/x/oauth2/google`
- Stretch: two-way sync between Sheets ↔ PostgreSQL, incremental updates

### 5.5. Google Drive backup / sync utility
A CLI that backs up a local folder to Drive or syncs changes.
- Concepts: OAuth2 with user consent and refresh tokens, resumable uploads of large files, concurrent uploads with a limit
- Stack: `google.golang.org/api/drive/v3`
- Stretch: delta sync by hashes, watching for changes, a progress bar and graceful shutdown

### 5.6. Gmail / Google Calendar automation
A rule-based inbox parser or a calendar event synchronizer.
- Concepts: OAuth2 with scopes, a background poller worker, idempotent processing (don't process an email twice)
- Stack: `google.golang.org/api/gmail/v1` or `calendar/v3`
- Stretch: push notifications via Pub/Sub instead of polling

### 5.7. Gaming APIs: Steam / Twitch / IGDB (gamedev fit)
A service around gaming data: a playtime and achievements tracker (Steam), stream monitoring by game (Twitch), a game catalog aggregator (IGDB/RAWG).
- Concepts: OAuth (Twitch), pagination and rate limiting, normalizing data from different sources, caching
- Stack: Steam Web API, Twitch Helix API, IGDB API
- Stretch: Twitch EventSub webhooks (notify when a streamer goes live), aggregating several APIs into one player profile
- Why it's good for a portfolio: it ties your domain to integration practice and resilience to third-party failures

### 5.8. LLM wrapper / AI-powered service
A service on top of an external LLM (Anthropic/OpenAI API): a summarizer, an assistant, a ticket classifier.
- Concepts: streaming responses (SSE), timeouts and retries on expensive calls, cost control, handling partial responses
- Stack: an HTTP client to the provider's API, optionally streaming
- Stretch: a cache for semantically similar requests, a queue limiting concurrent calls, observability on tokens and latency

### 5.9. Payment integration (Stripe) with webhooks
A mini subscription service: creating a checkout session, receiving and verifying webhooks.
- Concepts: idempotency, webhook signature verification, reliable event processing (outbox), secret safety
- Stack: `stripe-go`
- Stretch: state reconciliation with the provider, reprocessing failed webhooks from a DLQ

What these projects add to a portfolio that "local" ones don't: the ability to design a **resilient client to an unreliable external system**. This is exactly what's asked at middle/senior level — how you behave when someone else's API is slow, returns 429, or goes down. It's worth having at least one integration project with proper retries, backoff, and deadlines via `context`.

---

## How to pick your set

A minimal set for a middle/senior Go interview:

1. One Level 2 project — a concentrate of concurrency (2.1 crawler or 2.4 job queue). A clean `-race`.
2. One Level 3 project — 3.1 or 3.2, demonstrating production maturity (tests, Docker, CI, observability).
3. One Level 4 project — ideally 4.1, to tie Go concurrency to your gamedev domain and have something to discuss in depth.
4. Ideally one Level 5 project — an external API integration (e.g., 5.7 gamedev fit or 5.5 Google Drive), to show a resilient client to an unreliable external system.

## "Ready to show" checklist

- [ ] A `README` with description, architecture, and how to run (one command via docker-compose)
- [ ] Tests, including table-driven; for concurrent code, `go test -race` is clean
- [ ] `golangci-lint` with no warnings, code formatted with `gofmt`
- [ ] Clear package structure (no "god package"), idiomatic error handling
- [ ] Graceful shutdown, config via env, structured logs (`slog`)
- [ ] CI (GitHub Actions): build + test + lint
- [ ] A meaningful commit history (not a single "init" of 5000 lines)
- [ ] For high-load projects — benchmarks and a pprof profile in the README

---

Tip: start one Level 2 project right now, without planning for months. Working code on screen teaches you Go faster than any tutorial.
