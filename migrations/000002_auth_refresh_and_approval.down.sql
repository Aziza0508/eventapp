-- Migration: 000002_auth_refresh_and_approval (rollback)

DROP INDEX IF EXISTS idx_users_role_approved;
ALTER TABLE users DROP COLUMN IF EXISTS approved;
