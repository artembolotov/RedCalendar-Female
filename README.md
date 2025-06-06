# RedCalendar

Облачный трекер менструального цикла для iOS с собственным API сервером.

## О проекте

RedCalendar - это iOS приложение для отслеживания женского цикла, построенное на современной архитектуре SwiftUI + Redux с собственным backend API.

## Архитектура

### iOS приложение
- **SwiftUI** - современный UI framework
- **Redux архитектура** - предсказуемое управление состоянием
- **Dependency Injection** - ServiceLocator с `@Injected` property wrapper
- **Keychain** - безопасное хранение авторизационных данных
- **AppMetrica** - аналитика (Яндекс)

### Backend
- **Node.js + Express.js** - REST API сервер
- **PostgreSQL** - база данных
- **Firebase UID совместимость** - плавная миграция

## Структура проекта

```
RedCalendar/
├── app/                          # Backend API сервер
│   ├── hello.js                  # Основной сервер Express.js
│   ├── package.json              # Зависимости и конфигурация
│   ├── app.log                   # Логи приложения
│   ├── services/                 # Сервисы
│   │   ├── database.js           # PostgreSQL connection pool
│   │   ├── auth.js               # Сервис авторизации и миграции
│   │   ├── logger.js             # Система логирования
│   │   └── firebase-uid.js       # Генератор Firebase-совместимых UID
│   ├── api/                      # API маршруты
│   │   └── auth.js               # POST /auth/migrate, GET /auth/verify
│   ├── .eslintrc.js              # Конфигурация линтера
│   └── .eslintignore             # Исключения для ESLint
├── RedCalendar-Female/           # iOS приложение
│   ├── App/                      # Основные файлы приложения
│   │   ├── RedCalendar_FemaleApp.swift
│   │   └── Configurator.swift    # Настройка DI контейнера
│   ├── Core/                     # Базовая архитектура
│   │   ├── DI/                   # Dependency Injection
│   │   │   ├── ServiceLocator.swift
│   │   │   └── Injected.swift    # @Injected property wrapper
│   │   ├── Redux/                # Redux архитектура
│   │   │   ├── Store.swift       # Основной Store
│   │   │   ├── States/           # State модели
│   │   │   ├── Actions/          # Action модели
│   │   │   ├── Reducers/         # Reducers
│   │   │   └── Middleware/       # Middleware для async операций
│   │   ├── Services/             # Бизнес-логика
│   │   │   ├── AnalyticsService.swift
│   │   │   ├── KeychainService.swift
│   │   │   └── APIService.swift
│   │   └── Utils/
│   │       └── Logger.swift      # Логирование
│   ├── Features/                 # Функциональные модули
│   │   ├── Auth/Views/           # Авторизация
│   │   └── Home/Views/           # Главный экран
│   └── Common/Views/             # Общие компоненты
├── .github/workflows/            # CI/CD
│   └── netangels.yml             # Автодеплой на NetAngels
└── База данных RedCalendar - Документация.md
```

## API методы

| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/health` | Проверка состояния сервера |
| `POST` | `/auth/migrate` | Миграция с Firebase UID на device_id |
| `GET` | `/auth/verify` | Проверка валидности device_id |

## Авторизация

Система использует device_id для авторизации пользователей:

```bash
# Проверка device_id
curl -X GET https://api.calendar.red/auth/verify \
  -H "Authorization: Bearer abc123def456ghi789jkl012mno345"
```

## iOS архитектура

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

### iOS
1. Открыть `RedCalendar-Female.xcodeproj` в Xcode
2. Выбрать target `RedCalendar-Female`
3. Запустить на симуляторе или устройстве

## Проверка кода

### iOS
- Встроенный Swift Compiler в Xcode
- Xcode Analyzer для проверки архитектуры
- Unit тесты (планируются)



## Безопасность

- **Keychain** для хранения device_id
- **SSL/TLS** соединения с API
- **Type Safety** через Swift и Dependency Injection

## Логирование

### iOS логи
```swift
// Использование AppLogger
AppLogger.action(action)  // Логирование Redux actions
AppLogger.error("Migration failed", error: error)
AppLogger.stateChange("deviceId", oldValue: nil, newValue: "abc123")
```





## Технологии

### iOS
- **SwiftUI** - декларативный UI framework
- **Foundation** - базовые API
- **Security** - Keychain Services
- **AppMetricaCore** - аналитика от Яндекс

### Backend  
- **Node.js + Express.js** - REST API
- **PostgreSQL** - база данных

## Текущий статус

### ✅ Реализовано
- iOS Redux архитектура с полным state management
- Dependency Injection система с @Injected property wrapper  
- Keychain сервис для безопасного хранения данных
- API сервис для взаимодействия с backend
- Система авторизации через device_id
- Базовая структура API сервера
- Подключение к PostgreSQL БД

### 🔄 В разработке
- UI компоненты календаря и трекера
- CRUD операции для циклов и данных
- Push notifications через APNs



---

**Автор**: Артём Болотов  
**Версия**: 2.1.0  
**Последнее обновление**: 06.06.2025
