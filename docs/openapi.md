# API Reference — EventApp

Base URL: `http://localhost:8080`
Auth: `Authorization: Bearer <access_token>`

## Error Format (all errors)

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": { ... }
  }
}
```

| Code | HTTP | Description |
|---|---|---|
| VALIDATION_ERROR | 400 | Invalid input |
| CAPACITY_EXCEEDED | 400 | Event is full |
| INVALID_STATUS_TRANSITION | 400 | State machine violation |
| UNAUTHORIZED | 401 | Missing/invalid token |
| TOKEN_EXPIRED | 401 | JWT expired |
| FORBIDDEN | 403 | Insufficient role |
| NOT_FOUND | 404 | Resource not found |
| ALREADY_EXISTS / CONFLICT | 409 | Duplicate resource |
| INTERNAL_ERROR | 500 | Server error |

---

## Auth

### POST /auth/register

```bash
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "student@example.com",
    "password": "secret123",
    "full_name": "Asel Bekova",
    "role": "student",
    "city": "Almaty",
    "school": "School #42",
    "grade": 10
  }'
```

Response `201`:
```json
{
  "access_token": "eyJhbGci...",
  "user": {
    "id": 1,
    "email": "student@example.com",
    "full_name": "Asel Bekova",
    "role": "student",
    "city": "Almaty"
  }
}
```

### POST /auth/login

```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "student@example.com", "password": "secret123"}'
```

Response `200`: same as register response.

### GET /api/me

```bash
curl http://localhost:8080/api/me \
  -H "Authorization: Bearer $TOKEN"
```

Response `200`: `UserProfile` object.

---

## Events

### GET /api/events

```bash
# All events (paginated)
curl "http://localhost:8080/api/events?page=1&limit=20" \
  -H "Authorization: Bearer $TOKEN"

# With filters
curl "http://localhost:8080/api/events?city=Almaty&category=Robotics&format=offline" \
  -H "Authorization: Bearer $TOKEN"
```

Response `200`:
```json
{
  "data": [ { "id": 1, "title": "...", "date_start": "2025-03-01T10:00:00Z", ... } ],
  "total": 42,
  "page": 1,
  "limit": 20
}
```

### GET /api/events/:id

```bash
curl http://localhost:8080/api/events/1 -H "Authorization: Bearer $TOKEN"
```

### POST /api/events (organizer only)

```bash
curl -X POST http://localhost:8080/api/events \
  -H "Authorization: Bearer $ORG_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Robotics Olympiad 2025",
    "description": "Annual robotics competition for grades 8-11",
    "category": "Robotics",
    "format": "offline",
    "city": "Almaty",
    "date_start": "2025-04-10T09:00:00Z",
    "date_end": "2025-04-10T18:00:00Z",
    "capacity": 50
  }'
```

### PUT /api/events/:id (organizer/creator only)

Patch any fields — same body structure as POST.

### DELETE /api/events/:id (organizer/creator only)

```bash
curl -X DELETE http://localhost:8080/api/events/1 -H "Authorization: Bearer $ORG_TOKEN"
```

---

## Registrations

### POST /api/events/:id/apply

```bash
curl -X POST http://localhost:8080/api/events/1/apply \
  -H "Authorization: Bearer $STUDENT_TOKEN"
```

Response `201`:
```json
{ "id": 5, "user_id": 10, "event_id": 1, "status": "pending", "created_at": "..." }
```

Errors: `409 ALREADY_EXISTS` if already applied.

### GET /api/my/events

```bash
curl http://localhost:8080/api/my/events -H "Authorization: Bearer $STUDENT_TOKEN"
```

Response `200`: array of registrations with embedded event.

### GET /api/events/:id/participants (organizer only)

```bash
curl http://localhost:8080/api/events/1/participants \
  -H "Authorization: Bearer $ORG_TOKEN"
```

Response `200`: array of registrations with embedded user.

### PATCH /api/registrations/:id/status (organizer only)

```bash
curl -X PATCH http://localhost:8080/api/registrations/5/status \
  -H "Authorization: Bearer $ORG_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "approved"}'
```

Valid statuses: `approved`, `rejected`.
State machine violations return `400 INVALID_STATUS_TRANSITION`.

---

## Swagger UI

Доступен после запуска: **http://localhost:8080/swagger/index.html**

Обновить после изменения аннотаций:
```bash
make swag
```
