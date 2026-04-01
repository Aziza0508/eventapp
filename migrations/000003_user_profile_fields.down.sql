-- Migration: 000003_user_profile_fields (rollback)

ALTER TABLE users
    DROP COLUMN IF EXISTS phone,
    DROP COLUMN IF EXISTS bio,
    DROP COLUMN IF EXISTS avatar_url,
    DROP COLUMN IF EXISTS interests,
    DROP COLUMN IF EXISTS privacy_visible_to_organizers,
    DROP COLUMN IF EXISTS privacy_visible_to_school;
