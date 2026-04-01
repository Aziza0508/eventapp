-- Migration: 000004_event_enrichment_favorites (rollback)

DROP TABLE IF EXISTS favorites;

DROP INDEX IF EXISTS idx_events_tags;
DROP INDEX IF EXISTS idx_events_reg_deadline;
DROP INDEX IF EXISTS idx_events_is_free;

ALTER TABLE events
    DROP COLUMN IF EXISTS tags,
    DROP COLUMN IF EXISTS address,
    DROP COLUMN IF EXISTS latitude,
    DROP COLUMN IF EXISTS longitude,
    DROP COLUMN IF EXISTS organizer_contact,
    DROP COLUMN IF EXISTS additional_info,
    DROP COLUMN IF EXISTS reg_deadline,
    DROP COLUMN IF EXISTS is_free,
    DROP COLUMN IF EXISTS price,
    DROP COLUMN IF EXISTS poster_url,
    DROP COLUMN IF EXISTS checkin_token;
