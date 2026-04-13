# EventApp — local dev / diploma-demo Makefile.
# Canonical local-dev workflow:
#   make dev-up      → start Postgres + Redis (Docker)
#   make dev-seed    → wait for DB, apply schema, insert demo data
#   make run         → run the Go API on the host (talks to Docker infra)
# OR, in one shot:
#   make demo        → dev-up + dev-seed + run

.PHONY: help \
        run build test test-race vet lint \
        dev-up dev-down dev-reset dev-seed dev-logs demo \
        smoke smoke-clean \
        migrate-up migrate-down migrate-status \
        docker-up docker-down docker-logs \
        swag ios-gen clean

BINARY      := eventapp
CMD         := ./cmd/app
SEED_CMD    := ./cmd/seed
SMOKE_CMD   := ./cmd/smoke
MIGRATE_DIR := ./migrations

# Pulled from .env when targets call `set -a; . ./.env; set +a` (see scripts).
DB_PORT     ?= 5433
DB_USER     ?= postgres
DB_PASSWORD ?= postgres
DB_NAME     ?= eventapp
DB_URL      ?= postgres://$(DB_USER):$(DB_PASSWORD)@localhost:$(DB_PORT)/$(DB_NAME)?sslmode=disable

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# ── Local development (canonical path) ───────────────────────────────────────

run: ## Run the Go API on the host (requires .env + `make dev-up` infra)
	go run $(CMD)/main.go

build: ## Compile the API binary
	go build -o $(BINARY) $(CMD)/main.go

dev-up: ## Start Postgres + Redis in Docker (canonical infra)
	@./scripts/dev-up.sh

dev-down: ## Stop infra containers (keeps volumes)
	docker compose down

dev-reset: ## DESTRUCTIVE: stop infra and wipe DB/Redis volumes
	docker compose down -v

dev-seed: ## Apply schema (AutoMigrate) + insert demo data
	@./scripts/dev-seed.sh

dev-logs: ## Tail infra logs
	docker compose logs -f db redis

demo: ## One-shot diploma demo: infra → seed → run API
	@./scripts/dev-up.sh
	@./scripts/dev-seed.sh
	@echo ""
	@echo "→ Starting API on http://localhost:8080"
	@echo "→ Swagger:        http://localhost:8080/swagger/index.html"
	@echo ""
	@go run $(CMD)/main.go

# ── Smoke tests (real HTTP against running API) ──────────────────────────────

smoke: ## Run HTTP smoke suite against http://localhost:8080 (requires running API + seeded DB)
	@go run $(SMOKE_CMD)

# ── Tests ────────────────────────────────────────────────────────────────────

test: ## Run unit tests
	go test ./... -count=1

test-race: ## Run unit tests with race detector
	go test ./... -count=1 -race

vet: ## go vet
	go vet ./...

lint: ## golangci-lint
	golangci-lint run ./...

# ── SQL migrations (optional — AutoMigrate handles dev) ─────────────────────

migrate-up: ## Apply all pending SQL migrations (requires golang-migrate)
	@which migrate > /dev/null || (echo "Install: brew install golang-migrate" && exit 1)
	migrate -path $(MIGRATE_DIR) -database "$(DB_URL)" up

migrate-down: ## Roll back the last SQL migration
	@which migrate > /dev/null || (echo "Install: brew install golang-migrate" && exit 1)
	migrate -path $(MIGRATE_DIR) -database "$(DB_URL)" down 1

migrate-status: ## Show current migration version
	migrate -path $(MIGRATE_DIR) -database "$(DB_URL)" version

# ── Full-Docker path (optional) ──────────────────────────────────────────────

docker-up: ## Start FULL stack in Docker (db + redis + api). Slower; not the canonical path.
	docker compose --profile full up -d --build

docker-down: ## Stop full Docker stack
	docker compose --profile full down

docker-logs: ## Tail API logs from the docker stack
	docker compose --profile full logs -f app

# ── Tooling ──────────────────────────────────────────────────────────────────

swag: ## Re-generate Swagger docs from annotations
	@which swag > /dev/null || go install github.com/swaggo/swag/cmd/swag@latest
	swag init -g cmd/app/main.go -o docs

ios-gen: ## Generate the Xcode project from ios/project.yml
	@which xcodegen > /dev/null || (echo "Install: brew install xcodegen" && exit 1)
	cd ios && xcodegen generate

clean: ## Remove build artifacts and the local uploads directory
	rm -f $(BINARY)
	rm -rf uploads/
