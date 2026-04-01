-- Migration: 000003_user_profile_fields
-- Adds enriched profile fields to the users table for diploma requirements:
-- interests, phone, bio, avatar_url, and privacy settings.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS phone      VARCHAR(20),
    ADD COLUMN IF NOT EXISTS bio        TEXT            DEFAULT '',
    ADD COLUMN IF NOT EXISTS avatar_url TEXT            DEFAULT '',
    ADD COLUMN IF NOT EXISTS interests  TEXT[]          DEFAULT '{}';

-- Privacy settings stored as individual boolean columns for query simplicity.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS privacy_visible_to_organizers BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS privacy_visible_to_school     BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN users.interests IS 'Array of interest tags, e.g. {Robotics,Programming,AI}';
COMMENT ON COLUMN users.privacy_visible_to_organizers IS 'Whether organizers can see this profile in participant lists';
COMMENT ON COLUMN users.privacy_visible_to_school IS 'Whether the school administration can view this profile';
