-- Migration: 000006_notifications
-- Adds in-app notifications table and device token storage for push.

CREATE TABLE IF NOT EXISTS notifications (
    id         BIGSERIAL        PRIMARY KEY,
    user_id    BIGINT           NOT NULL REFERENCES users (id),
    type       VARCHAR(50)      NOT NULL,
    title      VARCHAR(255)     NOT NULL,
    body       TEXT             NOT NULL DEFAULT '',
    event_id   BIGINT           REFERENCES events (id),
    read       BOOLEAN          NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ      NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user       ON notifications (user_id, read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_event      ON notifications (event_id) WHERE event_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS device_tokens (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users (id),
    token      TEXT         NOT NULL,
    platform   VARCHAR(10)  NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_device_token UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens (user_id);
