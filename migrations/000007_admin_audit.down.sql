-- Migration: 000007_admin_audit (rollback)
DROP TABLE IF EXISTS audit_logs;
ALTER TABLE users DROP COLUMN IF EXISTS blocked;
