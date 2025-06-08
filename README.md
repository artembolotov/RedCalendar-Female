# RedCalendar iOS App

iOS приложение **RedCalendar** - облачный трекер менструального цикла, переписанный с UIKit на SwiftUI.

## Архитектура iOS приложения

- **SwiftUI** - современный UI framework
- **Redux архитектура** - предсказуемое управление состоянием
- **Keychain** - безопасное хранение авторизационных данных
- **AppMetrica** - аналитика (Яндекс)
- **Push Notifications** - получение уведомлений от сервера

## Структура проекта

```
RedCalendar-Female/           # iOS приложение SwiftUI
├── App/                      # Конфигурация приложения
│   ├── RedCalendar_FemaleApp.swift  # Главный файл SwiftUI App
│   ├── AppDelegate.swift     # UIKit делегат для push notifications
│   └── Configurator.swift    # Настройка DI контейнера
├── Core/                     # Основная логика
│   ├── Redux/                # Redux архитектура
│   │   ├── Store.swift       # Redux Store
│   │   ├── AppAction.swift   # Actions
│   │   ├── AppState.swift    # State
│   │   ├── AppReducer.swift  # Reducer
│   │   └── Middleware/       # Middleware
│   ├── Services/             # Сервисы
│   │   ├── AnalyticsService.swift   # Яндекс AppMetrica
│   │   ├── KeychainService.swift    # Безопасное хранение
│   │   ├── APIService.swift         # HTTP клиент
│   │   └── PushService.swift        # Push notifications
│   ├── DI/                   # Dependency Injection
│   │   ├── ServiceLocator.swift     # DI контейнер
│   │   └── Injected.swift          # Property wrapper
│   └── Utils/                # Утилиты и логгер
│       └── Logger.swift      # Система логирования
├── Features/                 # UI экраны
│   ├── Auth/Views/           # Авторизация
│   │   └── LoginView.swift   # Экран входа
│   └── Home/Views/           # Главный экран
│       └── HomeView.swift    # Домашний экран
└── Common/Views/             # Общие компоненты
    └── RootView.swift        # Корневой экран
```

## Push Notifications

### Архитектура уведомлений
- **APNs Auth Key** (.p8) - универсальный ключ для development и production
- **Silent Push** - фоновые обновления данных без показа пользователю
- **Device Token** - автоматическая регистрация и отправка на сервер
- **Background Mode** - обработка уведомлений когда приложение неактивно

### Настройки iOS приложения
- **Push Notifications** capability включена
- **Background Modes** → Remote notifications включен
- **Device Token** получается автоматически при запуске
- **Разрешения пользователя** запрашиваются отдельно (позже)

### Реализация

```swift
// PushService.swift - основной сервис
protocol PushServiceProtocol {
    func registerForRemoteNotifications()
    func updateAPNSToken(_ token: String) async
}

// AppDelegate.swift - получение токена
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Task {
        await pushService.updateAPNSToken(token)
    }
}
```

## Авторизация

### Миграция с Firebase

iOS приложение поддерживает плавную миграцию с Firebase Auth:

```swift
// Логика в AuthMiddleware.swift
case .checkAuth:
    // Priority 1: Check for device_id (new system)
    if let deviceId = keychain.getDeviceID() {
        return [.authCheckCompleted(deviceId: deviceId)]
    }
    
    // Priority 2: Check for legacy user_id (Firebase)
    if let userId = keychain.getUserUID() {
        return [.startMigration]
    }
    
    // No credentials found
    return [.authCheckCompleted(deviceId: nil)]
```

### Безопасное хранение

```swift
// KeychainService.swift
protocol KeychainServiceProtocol {
    // Device ID methods (new system)
    func getDeviceID() -> String?
    func saveDeviceID(_ deviceId: String) -> Bool
    func deleteDeviceID() -> Bool
    
    // User UID methods (Firebase legacy, for migration)
    func getUserUID() -> String?
    func saveUserUID(_ uid: String) -> Bool
    func deleteUserUID() -> Bool
}
```

## Redux архитектура

### State управление

```swift
// AppState.swift
struct AppState {
    var isCheckingAuth = true
    var userId: String?
    var deviceId: String?
    var isMigrating = false
    var migrationError: String?
    
    var isAuthenticated: Bool {
        deviceId != nil
    }
    
    var authCheckState: AuthCheckState {
        if isCheckingAuth { return .checking }
        if isMigrating || migrationError != nil { return .migrating }
        return deviceId != nil ? .authenticated : .notAuthenticated
    }
}
```

### Actions и Middleware

```swift
// AppAction.swift
enum AppAction {
    case checkAuth
    case authCheckCompleted(deviceId: String?)
    case startMigration
    case migrationCompleted(deviceId: String, userId: String)
    case migrationFailed(Error)
    case login
    case logout
}

// Middleware обрабатывают async операции
let authMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    // Асинхронная логика авторизации
}
```

## Dependency Injection

### Service Locator

```swift
// ServiceLocator.swift
final class ServiceLocator {
    public static let shared = ServiceLocator()
    
    func addService<T>(service: T) {
        let key = String(describing: T.self)
        services[key] = service
    }
    
    func getService<T>() -> T {
        let key = String(describing: T.self)
        guard let service = services[key] as? T else {
            fatalError("Service of type \(T.self) is not registered!")
        }
        return service
    }
}

// Injected.swift - Property wrapper
@propertyWrapper
struct Injected<Service> {
    private lazy var service: Service = ServiceLocator.shared.getService()
    
    public var wrappedValue: Service {
        mutating get { service }
    }
}
```

### Конфигурация

```swift
// Configurator.swift
final class Configurator {
    static let shared = Configurator()
    
    func setup() {
        registerAnalyticsService()
        registerKeychainService()
        registerAPIService()
        registerPushService()
    }
    
    private func registerPushService() {
        let pushService: PushServiceProtocol = PushService()
        ServiceLocator.shared.addService(service: pushService)
    }
}
```

## Требования и установка

### Системные требования
- **Xcode 15.0+**
- **iOS 17.0+**
- **Физическое устройство** для push notifications (симулятор не поддерживает)

### Установка
```bash
# Открыть в Xcode
open RedCalendar-Female.xcodeproj

# Настроить Team и Bundle ID
# Включить Push Notifications в Capabilities
# Включить Background Modes → Remote notifications
```

### Настройки проекта

#### Capabilities
- ✅ **Push Notifications** - включить
- ✅ **Background Modes** → Remote notifications - включить

#### Info.plist
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<key>NSUserNotificationsUsageDescription</key>
<string>Приложение использует уведомления для напоминаний о менструальном цикле.</string>
```

#### Entitlements
```xml
<!-- RedCalendar-Female.entitlements -->
<key>aps-environment</key>
<string>development</string>
```

## Аналитика

### AppMetrica интеграция

```swift
// AnalyticsService.swift
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
- `user_login` - вход пользователя
- `user_logout` - выход пользователя
- `migration_completed` - успешная миграция
- `migration_failed` - ошибка миграции
- `push_registration_failed` - ошибка регистрации push
- `apns_token_updated` - обновление APNS токена

## Логирование

### AppLogger

```swift
// Logger.swift
struct AppLogger {
    static func info(_ message: String) {
        #if DEBUG
        print("ℹ️ INFO: \(message)")
        #endif
    }
    
    static func warn(_ message: String) {
        #if DEBUG
        print("⚠️ WARN: \(message)")
        #endif
        // Отправка в аналитику
    }
    
    static func error(_ message: String, error: Error? = nil) {
        #if DEBUG
        print("❌ ERROR: \(message)")
        if let error = error {
            print("   Details: \(error.localizedDescription)")
        }
        #endif
        // Отправка в аналитику
    }
}
```

### Использование
```swift
AppLogger.info("Push permissions granted")
AppLogger.warn("Push permissions denied")
AppLogger.error("Migration failed", error: error)
```

## Тестирование

### Push Notifications
```bash
# iOS приложение должно логировать:
ℹ️ INFO: 🚀 Attempting to register for remote notifications...
ℹ️ INFO: 📱 Called registerForRemoteNotifications() on main thread
ℹ️ INFO: ✅ SUCCESS: Got APNS token: abc123def456...
ℹ️ INFO: APNS token updated successfully
```

### Проверка состояний Redux
```swift
// В RootView.swift автоматически отображается текущее состояние:
switch store.state.authCheckState {
case .checking:
    ProgressView("Проверка авторизации...")
case .migrating:
    ProgressView("Обновление системы авторизации...")
case .authenticated:
    HomeView()
case .notAuthenticated:
    LoginView()
}
```

### Диагностика проблем
- **Push не работают в симуляторе** - используйте реальное устройство
- **Токен не приходит** - проверьте Capabilities и Provisioning Profile
- **Ошибки миграции** - смотрите логи в консоли Xcode

## Безопасность

### Keychain хранение
- **Device ID** - основной идентификатор (28 символов, base62)
- **User UID** - legacy Firebase UID (для миграции)
- **Accessibility** - `kSecAttrAccessibleAfterFirstUnlock`
- **Synchronizable** - отключена для безопасности

### Push Notifications
- **APNS токены** передаются только по HTTPS
- **Device Token** уникален для каждого устройства
- **Silent Push** работает независимо от разрешений пользователя
- **Токены привязаны** к device_id для безопасности

## Архитектурные решения

### Почему Redux?
- **Предсказуемость** - единое место для состояния
- **Отладка** - легко отслеживать изменения
- **Тестируемость** - чистые функции
- **Асинхронность** - middleware для async операций

### Почему DI?
- **Тестируемость** - легко подменять зависимости
- **Слабая связанность** - сервисы не знают о реализации
- **Единая конфигурация** - все зависимости в одном месте

### Почему SwiftUI?
- **Современность** - актуальный фреймворк от Apple
- **Декларативность** - описываем что хотим, а не как
- **Производительность** - оптимизированный рендеринг
- **Интеграция** - отлично работает с Redux паттерном

---

**Автор**: Артём Болотов  
**Версия**: 2.1.0  
**Последнее обновление**: 08.06.2025

## Особенности iOS версии 2.1.0

- ✅ Полная поддержка Push Notifications
- ✅ Redux архитектура для управления состоянием
- ✅ Dependency Injection для слабой связанности
- ✅ Безопасное хранение в Keychain
- ✅ Автоматическая миграция с Firebase
- ✅ AppMetrica аналитика
- ✅ Минималистичная архитектура без избыточности
