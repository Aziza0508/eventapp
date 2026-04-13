#!/usr/bin/env bash
# Start the canonical local-dev infrastructure (Postgres + Redis) and
# block until both are healthy.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "→ No .env found — copying from .env.example"
  cp .env.example .env
fi

# Load env so docker compose substitution sees DB_PORT / REDIS_PORT.
set -a; . ./.env; set +a

echo "→ Starting Docker infra (db + redis)…"
docker compose up -d db redis

# Wait for healthchecks instead of a blind sleep.
wait_healthy() {
  local container="$1"
  local max=40
  local i=0
  while (( i < max )); do
    local status
    status="$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")"
    if [[ "$status" == "healthy" ]]; then
      echo "✓ $container is healthy"
      return 0
    fi
    sleep 0.5
    ((i++))
  done
  echo "✗ $container did not become healthy in time" >&2
  docker logs --tail=40 "$container" >&2 || true
  exit 1
}

wait_healthy eventapp-db
wait_healthy eventapp-redis

cat <<EOF

✓ Infrastructure ready.
  Postgres:  localhost:${DB_PORT:-5433}  (db=${DB_NAME:-eventapp} user=${DB_USER:-postgres})
  Redis:     localhost:${REDIS_PORT:-6380}

Next steps:
  make dev-seed     # apply schema + insert demo data
  make run          # start the Go API
  # OR  make demo   # do all of the above in one go
EOF
