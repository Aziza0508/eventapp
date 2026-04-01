-- Migration: 000006_notifications (rollback)
DROP TABLE IF EXISTS device_tokens;
DROP TABLE IF EXISTS notifications;
