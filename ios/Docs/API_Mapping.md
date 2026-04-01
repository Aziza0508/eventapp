# API Mapping — EventApp iOS ↔ Go Backend

> Source of truth: `internal/domain/`, `internal/delivery/http/dto/`, `internal/delivery/http/handler/`

---

## Date / ID Types

| Concern | Backend (Go) | iOS Swift | Notes |
|---------|-------------|-----------|-------|
| Dates | `time.Time` → RFC3339/ISO8601 | `Date` | `decoder.dateDecodingStrategy = .iso8601` in APIClient |
| IDs | `uint` (`BIGSERIAL`) | `Int` | Safe — no real ID > `Int.max` |
| Optional dates | `*time.Time` + `omitempty` | `Date?` | nil if not set |
| Paginated total | `int64` | `Int` | Safe cast |

---

## Event

Backend source: `internal/domain/event.go` + `internal/delivery/http/dto/event.go`

### JSON → Swift Mapping

| JSON key | Go type | Swift property | Swift type | Optional? | Notes |
|----------|---------|----------------|------------|-----------|-------|
| `id` | `uint` | `id` | `Int` | no | |
| `title` | `string` | `title` | `String` | no | |
| `description` | `string` | `description` | `String?` | yes | Empty string treated as nil |
| `category` | `string` | `category` | `String?` | yes | Free-form, e.g. "Robotics" |
| `format` | `EventFormat` | `format` | `EventFormat?` | yes | Enum: online/offline/hybrid |
| `city` | `string` | `city` | `String?` | yes | |
| `date_start` | `time.Time` | `dateStart` | `Date` | no | ISO8601 |
| `date_end` | `*time.Time` | `dateEnd` | `Date?` | yes | ISO8601, omitempty |
| `capacity` | `int` | `capacity` | `Int` | no | 0 = unlimited |
| `organizer_id` | `uint` | `organizerID` | `Int` | no | FK → User |
| `organizer` | `*User` | `organizer` | `User?` | yes | Embedded when loaded, omitempty |
| `created_at` | `time.Time` | `createdAt` | `Date` | no | ISO8601 |

> **Missing from iOS model:** `updated_at` — intentionally omitted (not needed by UI).

### EventFormat Enum

| Backend value | Swift case |
|---------------|------------|
| `"online"` | `.online` |
| `"offline"` | `.offline` |
| `"hybrid"` | `.hybrid` |

---

## User

Backend source: `internal/domain/user.go`

| JSON key | Go type | Swift property | Swift type | Optional? |
|----------|---------|----------------|------------|-----------|
| `id` | `uint` | `id` | `Int` | no |
| `email` | `string` | `email` | `String` | no |
| `full_name` | `string` | `fullName` | `String` | no |
| `role` | `UserRole` | `role` | `UserRole` | no |
| `city` | `string` | `city` | `String?` | yes (`omitempty`) |
| `school` | `string` | `school` | `String?` | yes (`omitempty`) |
| `grade` | `int` | `grade` | `Int?` | yes (`omitempty`) |

> `password_hash` is `json:"-"` — never sent to client.

### UserRole Enum

| Backend value | Swift case |
|---------------|------------|
| `"student"` | `.student` |
| `"organizer"` | `.organizer` |
| `"admin"` | `.admin` |

---

## Registration

Backend source: `internal/domain/registration.go`

| JSON key | Go type | Swift property | Swift type | Optional? |
|----------|---------|----------------|------------|-----------|
| `id` | `uint` | `id` | `Int` | no |
| `user_id` | `uint` | `userID` | `Int` | no |
| `event_id` | `uint` | `eventID` | `Int` | no |
| `status` | `RegStatus` | `status` | `RegStatus` | no |
| `event` | `*Event` | `event` | `Event?` | yes (`omitempty`) |
| `user` | `*User` | `user` | `User?` | yes (`omitempty`) |
| `created_at` | `time.Time` | `createdAt` | `Date` | no |

### RegStatus Enum + State Machine

| Backend value | Swift case | Valid next states |
|---------------|------------|-------------------|
| `"pending"` | `.pending` | `approved`, `rejected` |
| `"approved"` | `.approved` | `rejected` |
| `"rejected"` | `.rejected` | `approved` |

---

## Paginated Response: GET /api/events

```json
{
  "data":  [ ...Event ],
  "total": 42,
  "page":  1,
  "limit": 20
}
```

Swift: `EventListResponse { data: [Event], total: Int, page: Int, limit: Int }`

---

## Auth Response: POST /auth/register | /auth/login

```json
{
  "access_token": "eyJhbGci...",
  "user": { ...UserProfile }
}
```

Swift: `AuthResponse { accessToken: String, user: User }` (CodingKey: `access_token`)

---

## Error Envelope (all error responses)

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "resource not found"
  }
}
```

| Error Code | HTTP | iOS NetworkError case |
|------------|------|----------------------|
| `VALIDATION_ERROR` | 400 | `.validation(msg)` |
| `UNAUTHORIZED` | 401 | `.unauthorized` |
| `FORBIDDEN` | 403 | `.forbidden` |
| `NOT_FOUND` | 404 | `.notFound` |
| `ALREADY_EXISTS` / `CONFLICT` | 409 | `.conflict(msg)` |
| `INTERNAL_ERROR` | 500 | `.server(msg)` |

---

## Query Parameters: GET /api/events

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `city` | string | — | Case-insensitive LIKE filter |
| `category` | string | — | Case-insensitive LIKE filter |
| `format` | string | — | Exact match: `online`/`offline`/`hybrid` |
| `page` | int | 1 | 1-based |
| `limit` | int | 20 | Max 100 |
