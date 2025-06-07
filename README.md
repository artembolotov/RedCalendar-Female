# RedCalendar

iOS приложение для отслеживания женского цикла.

## О проекте

RedCalendar - это iOS приложение для отслеживания женского цикла, построенное на современной архитектуре SwiftUI + Redux.

## Архитектура

- **SwiftUI** - современный UI framework
- **Redux архитектура** - предсказуемое управление состоянием
- **Dependency Injection** - ServiceLocator с `@Injected` property wrapper
- **Keychain** - безопасное хранение авторизационных данных
- **AppMetrica** - аналитика (Яндекс)

## Структура проекта

```
RedCalendar-Female/
├── App/                          # Основные файлы приложения
│   ├── RedCalendar_FemaleApp.swift
│   └── Configurator.swift        # Настройка DI контейнера
├── Core/                         # Базовая архитектура
│   ├── DI/                       # Dependency Injection
│   │   ├── ServiceLocator.swift
│   │   └── Injected.swift        # @Injected property wrapper
│   ├── Redux/                    # Redux архитектура
│   │   ├── Store.swift           # Основной Store
│   │   ├── AppStore.swift        # Type alias для Store
│   │   ├── States/
│   │   │   └── AppState.swift
│   │   ├── Actions/
│   │   │   └── AppAction.swift
│   │   ├── Reducers/
│   │   │   └── AppReducer.swift
│   │   ├── Middleware/
│   │   │   ├── AppMiddleware.swift
│   │   │   ├── AuthMiddleware.swift
│   │   │   ├── MigrationMiddleware.swift
│   │   │   ├── LoggerMiddleware.swift
│   │   │   └── AnalyticsMiddleware.swift
│   │   └── AppMiddleware.swift
│   ├── Services/                 # Бизнес-логика
│   │   ├── AnalyticsService.swift
│   │   ├── KeychainService.swift
│   │   └── APIService.swift
│   └── Utils/
│       └── Logger.swift          # Логирование
├── Features/                     # Функциональные модули
│   ├── Auth/Views/
│   │   └── LoginView.swift
│   └── Home/Views/
│       └── HomeView.swift
└── Common/Views/                 # Общие компоненты
    └── RootView.swift
```



## Архитектура

### Dependency Injection

Система основана на ServiceLocator с элегантным `@Injected` property wrapper:

```swift
// Регистрация сервисов при старте
func setup() {
    let analytics: AnalyticsServiceProtocol = AnalyticsService()
    ServiceLocator.shared.addService(service: analytics)
    
    let keychain: KeychainServiceProtocol = KeychainService()
    ServiceLocator.shared.addService(service: keychain)
    
    let apiService: APIServiceProtocol = APIService()
    ServiceLocator.shared.addService(service: apiService)
}

// Использование в коде
class SomeClass {
    @Injected var analytics: AnalyticsServiceProtocol
    @Injected var keychain: KeychainServiceProtocol
    
    func doSomething() {
        analytics.trackEvent("action_performed")
        keychain.saveDeviceID("device123")
    }
}
```

### Redux State Management

```swift
// Actions
enum AppAction {
    case checkAuth
    case startMigration
    case migrationCompleted(deviceId: String, userId: String)
    case login
    case logout
}

// State
struct AppState {
    var isAuthenticated: Bool { deviceId != nil }
    var authCheckState: AuthCheckState { /* computed */ }
    var deviceId: String?
    var userId: String?
}

// Usage
@EnvironmentObject var store: AppStore
store.send(.checkAuth)
```

### Middleware Architecture

Асинхронная обработка через middleware:

```swift
let authMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    
    switch action {
    case .checkAuth:
        if let deviceId = keychain.getDeviceID() {
            return [.authCheckCompleted(deviceId: deviceId)]
        }
        if let userId = keychain.getUserUID() {
            return [.startMigration]
        }
        return [.authCheckCompleted(deviceId: nil)]
    }
    return []
}
```



## Установка и запуск

1. Открыть `RedCalendar-Female.xcodeproj` в Xcode
2. Выбрать target `RedCalendar-Female`
3. Запустить на симуляторе или устройстве

## Проверка кода

- Встроенный Swift Compiler в Xcode
- Xcode Analyzer для проверки архитектуры
- Unit тесты (планируются)



## Безопасность

- **Keychain** для хранения device_id
- **SSL/TLS** соединения с API
- **Type Safety** через Swift и Dependency Injection

## Логирование

```swift
// Использование AppLogger
AppLogger.action(action)  // Логирование Redux actions
AppLogger.error("Migration failed", error: error)
AppLogger.stateChange("deviceId", oldValue: nil, newValue: "abc123")
```



## Технологии

- **SwiftUI** - декларативный UI framework
- **Foundation** - базовые API
- **Security** - Keychain Services
- **AppMetricaCore** - аналитика от Яндекс

## Текущий статус

### ✅ Реализовано
- iOS Redux архитектура с полным state management
- Dependency Injection система с @Injected property wrapper  
- Keychain сервис для безопасного хранения данных
- API сервис для взаимодействия с backend
- Система авторизации через device_id

### 🔄 В разработке
- UI компоненты календаря и трекера
- CRUD операции для циклов и данных
- Push notifications через APNs



---

**Автор**: Артём Болотов  
**Версия**: 2.1.0  
**Последнее обновление**: 06.06.2025
