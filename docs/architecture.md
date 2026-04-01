# Architecture Decision Record — EventApp Backend

## Context

Дипломный проект: платформа соединяющая школьников и организаторов IT/робототехника мероприятий.
Цель — production-like MVP для защиты диплома, с чёткими архитектурными границами.

---

## Выбранный стиль: Modular Monolith (DDD-inspired)

### Почему не микросервисы сразу?

| Аспект | Монолит | Микросервисы |
|---|---|---|
| Скорость разработки | ✅ Высокая | ❌ Медленная (инфра) |
| Сложность деплоя | ✅ Один контейнер | ❌ Оркестрация (K8s) |
| Понятность для диплома | ✅ Прозрачно | ❌ Сложно объяснить |
| Путь к микросервисам | ✅ Заложен в структуре | — |

**Решение**: модульный монолит с доменными границами → легко разрезается на микросервисы позже.

---

## Слои приложения

```
cmd/app/main.go           ← точка входа, сборка зависимостей (DI вручную)
    │
    ├── config/           ← конфигурация из env-переменных
    │
    └── internal/
        ├── domain/       ← [ЯДРО] сущности + правила + ошибки
        │                    Нет зависимостей от БД, HTTP, внешних либ
        │
        ├── app/          ← [USECASES] бизнес-логика
        │                    Зависит только от domain + interfaces
        │                    Repositories и JWTProvider — интерфейсы (DI)
        │
        ├── infra/        ← [ИНФРАСТРУКТУРА] реализации интерфейсов
        │   ├── postgres/ ← GORM-репозитории
        │   └── jwt/      ← JWT-провайдер
        │
        └── delivery/     ← [HTTP] обработка запросов
            └── http/
                ├── handler/    ← gin-хэндлеры (только HTTP-логика)
                ├── middleware/  ← auth + RBAC + logger
                ├── dto/        ← request/response структуры
                ├── response/   ← единый формат ошибок
                └── router.go   ← регистрация маршрутов
```

### Правила зависимостей (Dependency Rule)
```
delivery → app → domain ← infra
```
- `domain` не зависит ни от чего
- `app` зависит только от `domain` (через интерфейсы)
- `infra` реализует интерфейсы из `app`
- `delivery` вызывает `app`, не знает о `infra`

---

## Доменные модули

| Модуль | Сущности | Ответственность |
|---|---|---|
| **identity** | User | регистрация, аутентификация, роли |
| **events** | Event | создание/редактирование событий, фильтры |
| **registrations** | Registration | заявки, статусы, state machine |
| *(future)* notifications | — | email/push уведомления (интерфейс-заглушка) |
| *(future)* files | — | загрузка изображений событий |

---

## Безопасность

- Пароли: `bcrypt` cost=14 (≈300ms на современном железе — защита от brute-force)
- JWT: HMAC-SHA256, TTL=24h, содержит `user_id` + `role`
- RBAC: `RequireRole` middleware на уровне роутера
- Privilege escalation guard: admin-роль недоступна через API (только прямо в БД)
- JWT_SECRET проверяется при старте (предупреждение если слабый)

---

## Путь к микросервисам

Если масштабировать, каждый доменный модуль становится сервисом:

```
[identity-service]   — /auth/*, /api/me
[events-service]     — /api/events/*
[registration-service] — /api/*/apply, /api/registrations/*
[api-gateway]        — маршрутизация + auth-проверка JWT
```

Структура папок уже готова: разделение по `internal/domain/*` и `internal/app/*`
позволяет вынести каждый модуль в отдельный репозиторий минимальными усилиями.

---

## iOS Architecture

```
SwiftUI View
    ↓ @StateObject / @EnvironmentObject
ViewModel (@MainActor ObservableObject)
    ↓ async/await
APIClient (URLSession)
    ↓ HTTP
Go Backend
```

- **AuthStore**: единый источник правды об аутентификации, инжектируется через `@EnvironmentObject`
- **Keychain**: хранение JWT токена
- **Loadable<T>**: унифицированное состояние загрузки (idle/loading/success/failure)
- **DI**: простой паттерн через конструктор, `APIClient.shared` для MVP
