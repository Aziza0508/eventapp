#!/usr/bin/env bash
# Apply schema (via the seed binary, which calls AutoMigrate) and insert
# the canonical demo data set.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "✗ No .env file. Run \`make dev-up\` first (it copies .env.example)." >&2
  exit 1
fi

set -a; . ./.env; set +a

echo "→ Running seed (AutoMigrate + demo data)…"
go run ./cmd/seed

cat <<EOF

✓ Database seeded.
  Admin login:      ${SEED_ADMIN_EMAIL:-admin@eventapp.local} / ${SEED_PASSWORD:-Password123!}
  Organizer logins: alma@robotics.kz, olzhas@codelab.kz, dana@iot.kz / ${SEED_PASSWORD:-Password123!}
  Student logins:   nurlan@school.kz, aisha@school.kz, daniyar@school.kz, samal@school.kz / ${SEED_PASSWORD:-Password123!}
EOF
