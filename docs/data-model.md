# Data Model — EventApp

## Entity Relationship

```
users ──────────────────── events
  │  1                  N   │  1
  │                         │
  │                    N    │
  └──── registrations ──────┘
           (user_id, event_id) UNIQUE
```

## Tables

### users

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | BIGSERIAL | PK | |
| email | VARCHAR(255) | UNIQUE NOT NULL | |
| password_hash | VARCHAR(255) | NOT NULL | bcrypt hash |
| role | VARCHAR(20) | DEFAULT 'student' | student/organizer/admin |
| full_name | VARCHAR(255) | NOT NULL | |
| school | VARCHAR(255) | | для школьников |
| city | VARCHAR(100) | | |
| grade | INT | CHECK 1-12 | класс школьника |
| created_at | TIMESTAMPTZ | | |
| updated_at | TIMESTAMPTZ | | |
| deleted_at | TIMESTAMPTZ | | soft delete |

### events

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | BIGSERIAL | PK | |
| title | VARCHAR(255) | NOT NULL | |
| description | TEXT | | |
| category | VARCHAR(100) | | Robotics, STEM, Coding… |
| format | VARCHAR(20) | online/offline/hybrid | |
| city | VARCHAR(100) | | |
| date_start | TIMESTAMPTZ | NOT NULL | |
| date_end | TIMESTAMPTZ | | опционально |
| capacity | INT | DEFAULT 0 | 0 = без ограничений |
| organizer_id | BIGINT | FK → users.id | |
| created_at | TIMESTAMPTZ | | |
| updated_at | TIMESTAMPTZ | | |
| deleted_at | TIMESTAMPTZ | | soft delete |

### registrations

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | BIGSERIAL | PK | |
| user_id | BIGINT | FK → users.id | студент |
| event_id | BIGINT | FK → events.id | |
| status | VARCHAR(20) | DEFAULT 'pending' | pending/approved/rejected |
| created_at | TIMESTAMPTZ | | |
| updated_at | TIMESTAMPTZ | | |
| deleted_at | TIMESTAMPTZ | | soft delete |
| — | — | UNIQUE(user_id, event_id) | один студент = одна заявка |

## Registration State Machine

```
          ┌─────────────┐
          │   pending   │ ← initial state on apply
          └──────┬──────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
  ┌──────────┐     ┌──────────┐
  │ approved │ ◄── │ rejected │
  └──────────┘     └──────────┘
        │
        └─► rejected  (organizer can reverse)
```

Transitions enforced by `domain.RegStatus.CanTransitionTo()`:
- `pending` → `approved` ✅
- `pending` → `rejected` ✅
- `approved` → `rejected` ✅ (organizer can reject after approval)
- `rejected` → `approved` ✅ (organizer can re-approve)
- Any → `pending` ❌ (can't go back to unreviewed)
- Same → Same ❌

## Indexes

Performance indexes pre-created in migration:
- `idx_users_email` — login lookup
- `idx_events_city`, `idx_events_category`, `idx_events_date_start` — event filters
- `idx_registrations_user`, `idx_registrations_event` — join queries
