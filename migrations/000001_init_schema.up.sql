-- Migration: 000001_init_schema
-- Creates the full initial schema for EventApp.
-- Run: make migrate-up

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL    PRIMARY KEY,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'student'
                               CHECK (role IN ('student', 'organizer', 'admin')),
    full_name     VARCHAR(255) NOT NULL,
    school        VARCHAR(255),
    city          VARCHAR(100),
    grade         INT          CHECK (grade IS NULL OR (grade >= 1 AND grade <= 12)),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_email      ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users (deleted_at);

-- Events table
CREATE TABLE IF NOT EXISTS events (
    id           BIGSERIAL    PRIMARY KEY,
    title        VARCHAR(255) NOT NULL,
    description  TEXT,
    category     VARCHAR(100),
    format       VARCHAR(20)  CHECK (format IS NULL OR format IN ('online', 'offline', 'hybrid')),
    city         VARCHAR(100),
    date_start   TIMESTAMPTZ  NOT NULL,
    date_end     TIMESTAMPTZ,
    capacity     INT          NOT NULL DEFAULT 0 CHECK (capacity >= 0), -- 0 = unlimited
    organizer_id BIGINT       NOT NULL REFERENCES users (id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_events_organizer   ON events (organizer_id);
CREATE INDEX IF NOT EXISTS idx_events_city        ON events (city);
CREATE INDEX IF NOT EXISTS idx_events_category    ON events (category);
CREATE INDEX IF NOT EXISTS idx_events_date_start  ON events (date_start);
CREATE INDEX IF NOT EXISTS idx_events_deleted_at  ON events (deleted_at);

-- Registrations table
CREATE TABLE IF NOT EXISTS registrations (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id),
    event_id   BIGINT      NOT NULL REFERENCES events (id),
    status     VARCHAR(20) NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,

    -- Prevent a user from registering to the same event twice
    CONSTRAINT uq_registration_user_event UNIQUE (user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_registrations_user       ON registrations (user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_event      ON registrations (event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_deleted_at ON registrations (deleted_at);
