# EventApp Makefile
# Usage: make <target>

.PHONY: run build test test-race lint vet docker-up docker-down docker-infra docker-logs \
        migrate-up migrate-down migrate-status swag ios-gen demo clean help

BINARY  := eventapp
CMD     := ./cmd/app
DB_URL  ?= postgres://postgres:password@localhost:5433/eventapp?sslmode=disable
MIGRATE_DIR := ./migrations

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ── Development ──────────────────────────────────────────────────────────────

run: ## Run the server locally (requires .env + running DB/Redis)
	go run $(CMD)/main.go

build: ## Compile the binary
	go build -o $(BINARY) $(CMD)/main.go

test: ## Run all unit tests
	go test ./... -v -count=1

test-race: ## Run tests with race detector
	go test ./... -v -count=1 -race

lint: ## Run golangci-lint
	golangci-lint run ./...

vet: ## Run go vet
	go vet ./...

# ── Database ─────────────────────────────────────────────────────────────────

migrate-up: ## Apply all pending migrations
	@which migrate > /dev/null || (echo "Install: brew install golang-migrate" && exit 1)
	migrate -path $(MIGRATE_DIR) -database "$(DB_URL)" up

migrate-down: ## Roll back the last migration
	@which migrate > /dev/null || (echo "Install: brew install golang-migrate" && exit 1)
	migrate -path $(MIGRATE_DIR) -database "$(DB_URL)" down 1

migrate-status: ## Show migration version
	migrate -path $(MIGRATE_DIR) -database "$(DB_URL)" version

# ── Docker ───────────────────────────────────────────────────────────────────

docker-up: ## Start full stack (db + redis + minio + app)
	docker compose up -d --build

docker-down: ## Stop and remove all containers
	docker compose down

docker-logs: ## Tail API logs
	docker compose logs -f app

docker-infra: ## Start only infrastructure (db + redis + minio) for local dev
	docker compose up -d db redis minio

# ── Swagger ──────────────────────────────────────────────────────────────────

swag: ## Re-generate Swagger docs from annotations
	@which swag > /dev/null || go install github.com/swaggo/swag/cmd/swag@latest
	swag init -g cmd/app/main.go -o docs

# ── iOS ──────────────────────────────────────────────────────────────────────

ios-gen: ## Generate Xcode project from ios/project.yml
	@which xcodegen > /dev/null || (echo "Install: brew install xcodegen" && exit 1)
	cd ios && xcodegen generate

# ── Demo (diploma defense) ───────────────────────────────────────────────────

demo: ## One-command startup: infra → migrations → server
	@echo "Starting infrastructure..."
	@docker compose up -d db redis minio
	@echo "Waiting for services to be ready..."
	@sleep 4
	@echo "Running migrations..."
	@make migrate-up 2>/dev/null || echo "(AutoMigrate will handle schema)"
	@echo "Starting EventApp server..."
	@go run $(CMD)/main.go

# ── Cleanup ──────────────────────────────────────────────────────────────────

clean: ## Remove build artifacts and uploads
	rm -f $(BINARY)
	rm -rf uploads/
