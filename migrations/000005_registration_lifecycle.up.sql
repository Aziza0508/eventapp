-- Migration: 000005_registration_lifecycle
-- Expands registration statuses and adds check-in tracking.

-- Expand the status CHECK constraint to include new lifecycle states.
ALTER TABLE registrations
    DROP CONSTRAINT IF EXISTS registrations_status_check;

ALTER TABLE registrations
    ADD CONSTRAINT registrations_status_check
        CHECK (status IN ('pending', 'approved', 'rejected', 'waitlisted', 'checked_in', 'completed', 'cancelled'));

-- Add checked_in_at timestamp for QR check-in audit.
ALTER TABLE registrations
    ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ;

-- Index for waitlist ordering (first-come-first-served promotion).
CREATE INDEX IF NOT EXISTS idx_registrations_waitlist
    ON registrations (event_id, created_at ASC)
    WHERE status = 'waitlisted' AND deleted_at IS NULL;
