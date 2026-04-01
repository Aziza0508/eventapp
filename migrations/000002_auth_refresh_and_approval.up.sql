-- Migration: 000002_auth_refresh_and_approval
-- 1. Adds organizer approval workflow (approved column on users).
-- 2. Refresh tokens are stored in Redis — no SQL table needed.

-- Organizer approval: students default true, organizers default false.
-- Admins are always approved (set manually).
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT true;

-- Existing organizers are grandfathered in as approved.
-- New organizers will be created with approved=false by the application layer.
COMMENT ON COLUMN users.approved IS 'Whether the account is approved. Organizers require admin approval.';

CREATE INDEX IF NOT EXISTS idx_users_role_approved ON users (role, approved) WHERE deleted_at IS NULL;
