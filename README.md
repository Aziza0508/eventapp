# EventApp

Platform connecting school students with IT/robotics event organizers.
Diploma project — Phase A (stabilization) is complete and the backend is
demo-ready.

**Backend:** Go 1.24 + Gin + GORM + PostgreSQL 15 + Redis 7
**iOS:** SwiftUI (MVVM) + Keychain + EventKit + AVFoundation
**Infrastructure:** Docker Compose (infra only) + GitHub Actions CI

---

## Architecture

```
cmd/app/main.go                  ← API entry point, DI wiring
cmd/seed/main.go                 ← demo-data seeder (used by `make dev-seed`)
cmd/smoke/main.go                ← HTTP smoke runner (used by `make smoke`)
internal/
  domain/                        ← entities, enums, errors (no deps)
  app/                           ← use cases + repository interfaces
  infra/postgres/                ← GORM repositories
  infra/redis/                   ← refresh-token store
  infra/jwt/                     ← JWT + refresh-token generation
  infra/notify/                  ← push / email senders
  infra/storage/                 ← local file uploads
  delivery/http/                 ← Gin handlers, middleware, DTOs, router
migrations/                      ← SQL migration files (000001–000007, optional)
scripts/                         ← dev-up.sh, dev-seed.sh
ios/EventApp/                    ← SwiftUI MVVM app
```

## Quick start (canonical local-dev path)

The supported workflow is **Docker for infra + Go on the host**. One command:

```bash
cp .env.example .env             # only on first run
make demo                        # infra → seed → API
```

`make demo` runs `dev-up`, then `dev-seed`, then the API. After that:

```
http://localhost:8080/health                 → {"status":"ok"}
http://localhost:8080/swagger/index.html     → Swagger UI
http://localhost:8080/metrics                → request counters
```

If you prefer the steps individually:

```bash
make dev-up      # start Postgres + Redis (waits for healthchecks)
make dev-seed    # AutoMigrate + insert 9 users + 18 events + registrations
make run         # start the Go API on http://localhost:8080
make smoke       # in another terminal — verifies the canonical flows
```

### Seeded credentials

Password for everyone: `Password123!` (override with `SEED_PASSWORD` in `.env`).

| Role | Email |
|---|---|
| admin | `admin@eventapp.local` |
| organizer (approved) | `alma@robotics.kz` |
| organizer (approved) | `olzhas@codelab.kz` |
| organizer (approved) | `dana@iot.kz` |
| organizer (pending — for admin demo) | `yerlan@newschool.kz` |
| student | `nurlan@school.kz` |
| student | `aisha@school.kz` |
| student | `daniyar@school.kz` |
| student | `samal@school.kz` |

The seed produces 18 events (12 upcoming + 4 past + 2 imminent) across
Robotics, Programming, AI/ML, Hackathon, Design, IoT, Workshop, and
Competition categories in Almaty, Astana, Shymkent, and online — plus
registrations covering every status the state machine supports
(pending, approved, rejected, waitlisted, checked_in, completed,
cancelled), favorites, and notifications.

### Common operations

```bash
make dev-down       # stop infra (keeps data volumes)
make dev-reset      # DESTRUCTIVE: stop infra and wipe DB/Redis volumes
make dev-seed       # re-seed (idempotent — TRUNCATEs first)
make smoke          # HTTP smoke suite
make test           # 18 unit tests (use cases)
```

### Optional: full Docker stack (everything in containers)

Slower iteration loop — use only for one-shot demos that should not
touch the host Go toolchain:

```bash
make docker-up      # builds the API image, starts db + redis + app
make docker-logs    # tail API logs
make docker-down    # stop the full stack
```

The full-stack `app` and `minio` services are gated behind compose
profiles (`full`, `minio`) so they don't start by accident with
`docker compose up`.

## iOS app

```bash
make ios-gen
open ios/EventApp.xcodeproj
```

The DEBUG build now defaults to **live** mode and points at
`http://localhost:8080`, so the simulator hits the seeded backend out of
the box. Mock data is still available as an opt-in toggle under
**Profile → Developer → Data Source** for offline UI work.

## Database migrations

GORM AutoMigrate runs on startup (and inside the seed command) so the
schema is always in sync. The numbered SQL migrations in
[`migrations/`](./migrations) document each schema change and remain
the authoritative reference for production deploys; you only need the
`golang-migrate` CLI if you intend to run them manually.

| # | Name | What it does |
|---|---|---|
| 1 | init_schema | users, events, registrations |
| 2 | auth_refresh_and_approval | organizer approval, refresh token prep |
| 3 | user_profile_fields | interests, phone, bio, avatar, privacy |
| 4 | event_enrichment_favorites | tags, address, price, poster, favorites |
| 5 | registration_lifecycle | waitlist, check-in, cancelled statuses |
| 6 | notifications | in-app notifications, device tokens |
| 7 | admin_audit | audit logs, user blocked field |

## API overview

**Auth:** register, login, refresh, logout
**Profile:** get/update profile, interests, privacy
**Events:** CRUD, advanced filters (search, tags, date range, free/paid), favorites, ICS calendar
**Registrations:** apply (auto-waitlist), cancel (auto-promote), QR check-in, CSV export
**Notifications:** in-app list, unread count, mark read, device-token registration
**Reports:** event attendance (JSON/CSV), organizer summary (JSON/CSV)
**Admin:** user management, block/unblock, role change, dashboard, audit logs

Full Swagger: <http://localhost:8080/swagger/index.html>

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `DB_HOST` | `localhost` | Postgres host (use `db` when running inside docker-compose) |
| `DB_PORT` | `5433` | Host-side mapped port for Postgres |
| `DB_USER` | `postgres` | DB user |
| `DB_PASSWORD` | `postgres` | DB password |
| `DB_NAME` | `eventapp` | Database name |
| `DB_SSLMODE` | `disable` | SSL mode |
| `REDIS_ADDR` | `localhost:6380` | Redis address (host-side) |
| `REDIS_PORT` | `6380` | Host-side mapped port for Redis |
| `JWT_SECRET` | — (required) | HMAC secret, ≥ 32 chars |
| `PORT` | `8080` | HTTP server port |
| `APP_ENV` | `development` | `development` / `production` |
| `PUBLIC_BASE_URL` | `http://localhost:8080` | Origin used to build absolute URLs (uploads, ICS). Set this for LAN/ngrok demos. |
| `SMTP_*` | — | Optional SMTP delivery |
| `SEED_PASSWORD` | `Password123!` | Password applied to every seeded user |
| `SEED_ADMIN_EMAIL` | `admin@eventapp.local` | Email of the seeded admin |

## Tests

```bash
make test            # 18 use-case unit tests
make test-race       # with race detector
make smoke           # HTTP smoke suite (requires running API + seeded DB)
make vet             # go vet
make lint            # golangci-lint (if installed)
```

## Observability

| Endpoint | Purpose |
|---|---|
| `GET /health`  | liveness probe |
| `GET /ready`   | readiness probe |
| `GET /metrics` | request counters, latency buckets, uptime |

Every request is logged as
`[request_id] METHOD PATH | status=CODE latency=DURATION user=USER_ID`.
