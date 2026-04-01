-- Migration: 000007_admin_audit
-- Adds audit_logs table and blocked column on users.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS blocked BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS audit_logs (
    id          BIGSERIAL    PRIMARY KEY,
    actor_id    BIGINT       NOT NULL REFERENCES users (id),
    action      VARCHAR(50)  NOT NULL,
    entity_type VARCHAR(30)  NOT NULL,
    entity_id   BIGINT       NOT NULL DEFAULT 0,
    summary     TEXT         DEFAULT '',
    ip          VARCHAR(45)  DEFAULT '',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_actor    ON audit_logs (actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_action   ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_created  ON audit_logs (created_at DESC);
