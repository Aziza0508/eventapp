# EventApp

Platform connecting school students with IT/robotics event organizers.

**Backend:** Go 1.24 + Gin + GORM + PostgreSQL + Redis  
**iOS:** SwiftUI (MVVM) + Keychain + EventKit + AVFoundation  
**Infrastructure:** Docker Compose + GitHub Actions CI

---

## Architecture

```
cmd/app/main.go                  ← Entry point, DI wiring
internal/
  domain/                        ← Entities, enums, errors (no deps)
  app/                           ← Use cases + repository interfaces
  infra/postgres/                ← GORM repositories
  infra/redis/                   ← Refresh token store
  infra/jwt/                     ← JWT + refresh token generation
  infra/notify/                  ← Push/email senders
  infra/storage/                 ← Local file uploads
  delivery/http/                 ← Gin handlers, middleware, DTOs, router
migrations/                      ← SQL migration files (000001–000007)
ios/EventApp/                    ← SwiftUI MVVM app
```

## Quick Start (Local Development)

### Prerequisites

- Go 1.24+
- Docker + Docker Compose
- (Optional) `golang-migrate` CLI: `brew install golang-migrate`
- (Optional for iOS) Xcode 16+, `xcodegen`: `brew install xcodegen`

### 1. Clone and configure

```bash
git clone <repo-url> && cd eventapp-main
cp .env.example .env
# Edit .env — set a strong JWT_SECRET:
#   openssl rand -hex 32
```

### 2. Start infrastructure

```bash
make docker-infra    # Starts PostgreSQL + Redis + MinIO
```

### 3. Run the server

```bash
make run             # Applies AutoMigrate + starts on :8080
```

### 4. Verify

```bash
curl http://localhost:8080/health     # → {"status":"ok"}
curl http://localhost:8080/metrics    # → request counters
open http://localhost:8080/swagger/index.html   # Swagger UI
```

### One-Command Demo (Diploma Defense)

```bash
make demo
```

This starts infrastructure, runs migrations, and launches the API server.

## iOS App

```bash
make ios-gen         # Generate Xcode project
open ios/EventApp.xcodeproj
```

- In **DEBUG** mode, the app uses mock data by default (no backend required).
- Toggle **Live** mode in Profile → Developer → Data Source to connect to the backend.
- Base URL: `http://localhost:8080` (configured in `APIClient.swift`).

## Docker Compose Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `db` | postgres:15-alpine | 5432 | Primary database |
| `redis` | redis:7-alpine | 6379 | Refresh token store |
| `minio` | minio/minio | 9000/9001 | S3-compatible object storage |
| `app` | eventapp (built) | 8080 | Go API server |

```bash
make docker-up       # Full stack (build + start all)
make docker-down     # Stop all
make docker-logs     # Tail API logs
make docker-infra    # Only infrastructure (for local dev)
```

## Database Migrations

7 migration files in `migrations/`:

| # | Name | What it does |
|---|------|-------------|
| 1 | init_schema | users, events, registrations |
| 2 | auth_refresh_and_approval | organizer approval, refresh token prep |
| 3 | user_profile_fields | interests, phone, bio, avatar, privacy |
| 4 | event_enrichment_favorites | tags, address, price, poster, favorites |
| 5 | registration_lifecycle | waitlist, check-in, cancelled statuses |
| 6 | notifications | in-app notifications, device tokens |
| 7 | admin_audit | audit logs, user blocked field |

```bash
make migrate-up      # Apply all pending
make migrate-down    # Roll back one
make migrate-status  # Current version
```

GORM AutoMigrate runs on startup as a safety net, but production should use explicit migrations.

## API Overview

**Auth:** register, login, refresh, logout  
**Profile:** get/update profile, interests, privacy  
**Events:** CRUD, advanced filters (search, tags, date range, free/paid), favorites, ICS calendar  
**Registrations:** apply (auto-waitlist), cancel (auto-promote), QR check-in, CSV export  
**Notifications:** in-app list, unread count, mark read, device token registration  
**Reports:** event attendance (JSON/CSV), organizer summary (JSON/CSV)  
**Admin:** user management, block/unblock, role change, dashboard, audit logs  

Full Swagger docs: http://localhost:8080/swagger/index.html

## Environment Variables

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `DB_HOST` | localhost | Yes | PostgreSQL host |
| `DB_PORT` | 5432 | Yes | PostgreSQL port |
| `DB_USER` | postgres | Yes | DB user |
| `DB_PASSWORD` | password | Yes | DB password |
| `DB_NAME` | eventapp | Yes | Database name |
| `DB_SSLMODE` | disable | | SSL mode |
| `REDIS_ADDR` | localhost:6379 | Yes | Redis address |
| `JWT_SECRET` | — | **Yes** | HMAC secret (32+ chars) |
| `PORT` | 8080 | | HTTP server port |
| `APP_ENV` | development | | development/production |
| `SMTP_ENABLED` | false | | Enable email delivery |
| `SMTP_HOST` | — | | SMTP server |
| `SMTP_PORT` | 587 | | SMTP port |
| `SMTP_USER` | — | | SMTP username |
| `SMTP_PASSWORD` | — | | SMTP password |
| `SMTP_FROM` | EventApp | | From header |

## Testing

```bash
make test            # 88 unit tests
make test-race       # With race detector
make vet             # Go vet
make lint            # golangci-lint (if installed)
```

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on push/PR to `main`:
- **Backend:** build, test (with Postgres + Redis services), vet
- **Swagger:** validates docs are up-to-date
- **Docker:** verifies image builds successfully

## Observability

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Liveness probe |
| `GET /ready` | Readiness probe |
| `GET /metrics` | Request counters, latency buckets, uptime |

Every request is logged with: `[request_id] METHOD PATH | status=CODE latency=DURATION user=USER_ID`

## Project Structure (iOS)

```
ios/EventApp/
  App/           → Entry point, ContentView, OnboardingView, AppDelegate
  Auth/          → AuthStore, LoginView, RegisterView
  Domain/        → Codable models (User, Event, Registration, etc.)
  Network/       → APIClient, Endpoint definitions
  Data/          → Repository protocols + Live/Mock implementations
  Storage/       → KeychainManager, EventCache
  Events/        → EventListView, EventDetailView + ViewModels
  MyEvents/      → MyEventsView + ViewModel
  Organizer/     → Dashboard, CreateEvent, Participants, QRScanner
  Profile/       → ProfileView, EditProfileView + ViewModel
  Shared/        → Loadable<T>, CalendarHelper
  DesignSystem/  → AppTheme, Buttons, InputFields, FilterChip
  Components/    → EventCard, StatusBadge, CategoryBadge
  Mock/          → MockEventFactory (14 events), MockRepositories
```
