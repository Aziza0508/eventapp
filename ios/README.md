# EventApp — iOS

SwiftUI application для платформы EventApp.

## Архитектура

```
MVVM + EnvironmentObject для AuthStore
     ↓
APIClient (async/await, Codable)
     ↓
REST API (Go backend)
```

## Структура файлов

```
ios/EventApp/
├── App/
│   ├── EventAppApp.swift      — точка входа (@main)
│   └── ContentView.swift      — root view + TabView
├── Domain/
│   └── Models.swift           — User, Event, Registration, enums
├── Network/
│   ├── APIClient.swift        — URLSession wrapper, error mapping
│   └── Endpoint.swift         — все эндпоинты + request bodies
├── Storage/
│   └── KeychainManager.swift  — безопасное хранение JWT
├── Auth/
│   ├── AuthStore.swift        — ObservableObject, хранит User + token
│   ├── LoginView.swift
│   └── RegisterView.swift
├── Events/
│   ├── EventListViewModel.swift
│   ├── EventListView.swift     — список с фильтрами + infinite scroll
│   ├── EventDetailViewModel.swift
│   └── EventDetailView.swift   — детали + кнопка Apply
├── MyEvents/
│   ├── MyEventsViewModel.swift
│   └── MyEventsView.swift      — регистрации студента со статусами
├── Profile/
│   └── ProfileView.swift
├── Organizer/
│   ├── CreateEventView.swift   — форма создания события
│   ├── OrganizerDashboardView.swift — дашборд организатора
│   └── ParticipantsView.swift  — список участников + approve/reject
├── Components/
│   └── EventCard.swift         — переиспользуемые компоненты UI
└── Shared/
    └── Loadable.swift          — enum Loading/Success/Failure
```

## Как создать Xcode-проект

1. Открой Xcode → **File → New → Project**
2. Выбери **iOS → App**
3. Product Name: `EventApp`, Bundle ID: `com.eventapp.app`, Interface: `SwiftUI`, Language: `Swift`
4. Сохрани проект в папку `ios/`
5. В Xcode выбери **File → Add Files to "EventApp"** и добавь все `.swift` файлы из `ios/EventApp/`
6. Убедись, что `EventAppApp.swift` установлен как точка входа

## Настройка API URL

В `ios/EventApp/Network/APIClient.swift`, строка `init`:
```swift
// Замени для реального сервера:
baseURL: URL(string: "https://your-server.com")!

// Для локального запуска iOS симулятора:
baseURL: URL(string: "http://localhost:8080")!
```

## Требования

- Xcode 15+
- iOS 16+
- Swift 5.9+
