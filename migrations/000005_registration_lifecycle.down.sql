-- Migration: 000005_registration_lifecycle (rollback)

DROP INDEX IF EXISTS idx_registrations_waitlist;

ALTER TABLE registrations DROP COLUMN IF EXISTS checked_in_at;

ALTER TABLE registrations
    DROP CONSTRAINT IF EXISTS registrations_status_check;

ALTER TABLE registrations
    ADD CONSTRAINT registrations_status_check
        CHECK (status IN ('pending', 'approved', 'rejected'));
