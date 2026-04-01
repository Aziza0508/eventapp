-- Migration: 000004_event_enrichment_favorites
-- 1. Enriches events table with diploma-required fields.
-- 2. Creates favorites (bookmarks) table.

-- ── Enrich events ────────────────────────────────────────────────────────────
ALTER TABLE events
    ADD COLUMN IF NOT EXISTS tags              TEXT[]       DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS address           TEXT         DEFAULT '',
    ADD COLUMN IF NOT EXISTS latitude          DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude         DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS organizer_contact TEXT         DEFAULT '',
    ADD COLUMN IF NOT EXISTS additional_info   TEXT         DEFAULT '',
    ADD COLUMN IF NOT EXISTS reg_deadline      TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_free           BOOLEAN      NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS price             DECIMAL(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS poster_url        TEXT         DEFAULT '',
    ADD COLUMN IF NOT EXISTS checkin_token     VARCHAR(64)  DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_events_is_free      ON events (is_free)   WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_events_reg_deadline  ON events (reg_deadline) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_events_tags          ON events USING GIN (tags) WHERE deleted_at IS NULL;

-- ── Favorites / bookmarks ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS favorites (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id),
    event_id   BIGINT      NOT NULL REFERENCES events (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_favorite_user_event UNIQUE (user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user  ON favorites (user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_event ON favorites (event_id);
