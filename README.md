# RedCalendar iOS

iOS приложение **RedCalendar** - облачный трекер менструального цикла, переписанный с UIKit на SwiftUI с собственной серверной инфраструктурой.

## Архитектура

### Основные компоненты
- **SwiftUI** - современный UI framework
- **Redux архитектура** - предсказуемое управление состоянием через Store/Actions/Reducers
- **Dependency Injection** - слабая связанность компонентов через ServiceLocator
- **Keychain** - безопасное хранение авторизационных данных
- **AppMetrica** - аналитика Яндекса
- **APNs** - push уведомления

### Структура проекта

```
RedCalendar-Female/
├── App/                          # Конфигурация приложения
│   ├── RedCalendar_FemaleApp.swift     # Главный файл SwiftUI App
│   ├── AppDelegate.swift               # UIKit делегат для push
│   └── Configurator.swift              # Настройка DI контейнера
├── Core/                         # Основная логика
│   ├── Redux/                    # Redux архитектура
│   │   ├── Store.swift           # Основной Store
│   │   ├── Actions/              # Actions
│   │   ├── States/               # State модели
│   │   ├── Reducers/             # Reducers
│   │   └── Middleware/           # Async middleware
│   ├── Services/                 # Сервисы
│   │   ├── AnalyticsService.swift      # Яндекс AppMetrica
│   │   ├── KeychainService.swift       # Безопасное хранение
│   │   ├── APIService.swift            # HTTP клиент
│   │   └── PushPermissionService.swift # Push разрешения
│   ├── Models/                   # Модели данных
│   │   ├── AuthState.swift       # Состояния авторизации
│   │   ├── APNSToken.swift       # APNS токен
│   │   └── UserDetails.swift     # Данные пользователя
│   ├── DI/                       # Dependency Injection
│   │   ├── ServiceLocator.swift  # DI контейнер
│   │   └── Injected.swift        # Property wrapper
│   └── Utils/                    # Утилиты
│       └── Logger.swift          # Система логирования
├── Features/                     # UI экраны
│   ├── Auth/Views/               # Авторизация
│   │   └── LoginView.swift       # Экран входа
│   └── Home/Views/               # Главный экран
│       └── HomeView.swift        # Домашний экран
└── Common/Views/                 # Общие компоненты
    └── RootView.swift            # Корневой экран с роутингом
```

## Redux архитектура

### AppState - глобальное состояние
```swift
struct AppState {
    var apnsToken: APNSToken?
    var authState: AuthState?
    var pushPermissionState: PushPermissionState?
}
```

### AppAction - действия
```swift
enum AppAction {
    case checkAuth
    case setAuthState(_ state: AuthState)
    case setAPNSToken(_ token: APNSToken)
    case setPushPermissionState(_ state: PushPermissionState?)
    case retryFailedTasks
}
```

### Middleware - асинхронная логика
- **AuthMiddleware** - проверка авторизации и миграция с Firebase
- **MigrationMiddleware** - конвертация Firebase UID в device_id
- **PushNotificationMiddleware** - управление APNS токенами
- **AnalyticsMiddleware** - отправка событий в AppMetrica

## Авторизация

### Миграция с Firebase
Приложение автоматически мигрирует пользователей с Firebase Auth на собственную систему:

```swift
// Логика в AuthMiddleware
case .checkAuth:
    // Приоритет 1: Ищем device_id (новая система)
    if let deviceId = keychain.getDeviceID() {
        return [.setAuthState(.authenticated(deviceId: deviceId, userDetails: nil))]
    }
    
    // Приоритет 2: Ищем legacy user_id (Firebase)
    if let userId = keychain.getUserUID() {
        return [.setAuthState(.migrating(userId: userId, error: nil))]
    }
    
    // Нет учетных данных
    return [.setAuthState(.notAuthenticated)]
```

### Состояния авторизации
```swift
enum AuthState {
    case notAuthenticated
    case authenticated(deviceId: String, userDetails: UserDetails?)
    case migrating(userId: String, error: Error?)
}
```

### Keychain хранение
```swift
protocol KeychainServiceProtocol {
    // Device ID (новая система)
    func getDeviceID() -> String?
    func saveDeviceID(_ deviceId: String) -> Bool
    func deleteDeviceID() -> Bool
    
    // User UID (Firebase legacy, для миграции)
    func getUserUID() -> String?
    func saveUserUID(_ uid: String) -> Bool
    func deleteUserUID() -> Bool
}
```

## Push Notifications

### Архитектура уведомлений
- **Background Mode** - Remote notifications включен
- **Device Token** - автоматическая регистрация при авторизации
- **APNS токены** - синхронизация с сервером через API
- **Разрешения** - запрос только после авторизации

### Реализация
```swift
// AppDelegate.swift - получение токена
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    appStore?.send(.setAPNSToken(APNSToken(value: token, isSynced: false)))
}
```

### Состояния разрешений
```swift
enum PushPermissionState {
    case notAsked     // Еще не спрашивали
    case denied       // Пользователь отказал
    case authorized   // Разрешено
}
```

## Dependency Injection

### ServiceLocator
```swift
final class ServiceLocator {
    static let shared = ServiceLocator()
    
    func addService<T>(service: T) { /* ... */ }
    func getService<T>() -> T { /* ... */ }
}
```

### @Injected Property Wrapper
```swift
@propertyWrapper
struct Injected<Service> {
    private lazy var service: Service = ServiceLocator.shared.getService()
    public var wrappedValue: Service { /* ... */ }
}

// Использование
struct SomeView: View {
    @Injected var apiService: APIServiceProtocol
}
```

### Конфигурация сервисов
```swift
// Configurator.swift
final class Configurator {
    static let shared = Configurator()
    
    func setup() {
        registerAnalyticsService()
        registerKeychainService()
        registerAPIService()
        registerPushPermissionsService()
    }
}
```

## API интеграция

### APIService
```swift
protocol APIServiceProtocol {
    func migrateUser(userId: String) async throws -> MigrationResponse
    func verifyDevice(deviceId: String) async throws -> VerificationResponse
    func updateAPNSToken(deviceId: String, apnsToken: String) async throws -> APNSTokenResponse
}
```

### Модели ответов
```swift
struct MigrationResponse: Codable {
    let success: Bool
    let data: MigrationData?
    let message: String?
    let timestamp: String
}

struct VerificationResponse: Codable {
    let success: Bool
    let data: VerificationData?
    let timestamp: String
}
```

## Аналитика

### AppMetrica интеграция
```swift
final class AnalyticsService: AnalyticsServiceProtocol {
    private let apiKey = "***REMOVED***"
    
    func registerApp() {
        let configuration = AppMetricaConfiguration(apiKey: apiKey)
        AppMetrica.activate(with: configuration!)
    }
    
    func trackEvent(_ name: String, parameters: [AnyHashable : Any]? = nil) {
        AppMetrica.reportEvent(name: name, parameters: parameters)
    }
}
```

### Отслеживаемые события
- Успешная/неуспешная миграция
- Ошибки регистрации push уведомлений
- Предупреждения и ошибки приложения

## Логирование

### AppLogger
```swift
struct AppLogger {
    static func info(_ message: String)
    static func warn(_ message: String)    // + отправка в аналитику
    static func error(_ message: String, error: Error?)  // + отправка в аналитику
    static func action(_ action: AppAction)  // Redux actions в DEBUG
}
```

## Конфигурация проекта

### Capabilities
- ✅ **Push Notifications** 
- ✅ **Background Modes** → Remote notifications

### Info.plist
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Entitlements
```xml
<key>aps-environment</key>
<string>development</string>
```

### Требования
- **iOS 15.4+**
- **Xcode 15.0+**
- **Физическое устройство** для тестирования push уведомлений

## Тестирование

### Проверка авторизации
```swift
// В RootView автоматически отображается состояние:
switch store.state.authState {
case nil:
    ProgressView("Проверка авторизации...")
case .notAuthenticated:
    LoginView()
case .migrating(_, let error):
    // UI для миграции с возможностью повтора при ошибке
case .authenticated:
    HomeView()
}
```

### Логи Redux Actions
```
🎯 Action: checkAuth
🎯 Action: setAuthState(migrating("nSJXOCPF3ocA4Znn1sL7KvI1dh13", nil))
🎯 Action: setAuthState(authenticated("abc123def456", nil))
```

### Push Notifications
```
ℹ️ INFO: Got APNS token: abc123def456...
ℹ️ INFO: Apns token synced
```

### Диагностика проблем
- **Push не работают в симуляторе** - только на реальном устройстве
- **Токен не приходит** - проверить Capabilities и Provisioning Profile
- **Ошибки миграции** - смотреть логи в консоли Xcode

## Безопасность

### Keychain
- **Accessibility** - `kSecAttrAccessibleAfterFirstUnlock`
- **Synchronizable** - отключена для безопасности
- **Device ID** - 28-символьный Firebase-style UID

### API
- **HTTPS** - все запросы только по защищенному соединению
- **Authorization** - Bearer token в заголовках
- **Device ID** - уникальный идентификатор устройства

## Архитектурные решения

### Почему Redux?
- **Предсказуемость** - единое место для состояния приложения
- **Отладка** - легко отслеживать все изменения состояния
- **Тестируемость** - чистые функции reducers
- **Асинхронность** - middleware для side effects

### Почему DI?
- **Тестируемость** - легко подменять зависимости в тестах
- **Слабая связанность** - компоненты не знают о конкретных реализациях
- **Единая точка конфигурации** - все зависимости настраиваются в одном месте

### Почему SwiftUI?
- **Современность** - актуальный фреймворк от Apple
- **Декларативность** - описываем что хотим, не как это сделать
- **Производительность** - оптимизированный рендеринг
- **Реактивность** - отличная интеграция с Redux через @EnvironmentObject

---

**Автор**: Артём Болотов  
**Версия**: 3.0  
**Последнее обновление**: 09.06.2025
