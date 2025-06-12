# RedCalendar iOS

iOS приложение **RedCalendar** - облачный трекер менструального цикла, переписанный с UIKit на SwiftUI с собственной серверной инфраструктурой.

## Архитектура

### Основные технологии
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
│   │   ├── Store.swift           # Основной Store с Middleware поддержкой
│   │   ├── AppStore.swift        # Type alias для удобства
│   │   ├── AppMiddleware.swift   # Комбинирование middleware
│   │   ├── Actions/              # Actions
│   │   │   └── AppAction.swift   # Все действия приложения
│   │   ├── States/               # State модели
│   │   │   └── AppState.swift    # Главное состояние
│   │   ├── Reducers/             # Reducers
│   │   │   └── AppReducer.swift  # Основной reducer
│   │   └── Middleware/           # Async middleware
│   │       ├── LoggerMiddleware.swift     # Логирование actions
│   │       ├── AuthMiddleware.swift       # Авторизация
│   │       ├── MigrationMiddleware.swift  # Firebase миграция
│   │       ├── PushNotificationsMiddleware.swift # Push уведомления
│   │       └── AnalyticsMiddleware.swift  # Аналитика
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
    // Auth actions
    case setAuthState(_ state: AuthState?)
    
    // Push notification actions
    case setAPNSToken(_ token: APNSToken)
    case setPushPermissionState(_ state: PushPermissionState?)
    
    // Retry actions
    case retryFailedTasks
}
```

### Middleware - асинхронная логика
- **LoggerMiddleware** - логирование всех actions в DEBUG режиме
- **AuthMiddleware** - проверка авторизации и миграция с Firebase
- **MigrationMiddleware** - конвертация Firebase UID в device_id
- **PushNotificationMiddleware** - управление APNS токенами
- **AnalyticsMiddleware** - отправка событий в AppMetrica

### Store конфигурация
```swift
@StateObject private var store = AppStore(
    initialState: AppState(),
    reducer: appReducer,
    middlewares: combineAppMiddlewares()
)
```

## Авторизация

### Миграция с Firebase
Приложение автоматически мигрирует пользователей с Firebase Auth на собственную систему:

```swift
// Логика в AuthMiddleware
case .setAuthState(nil):
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

## Push Notifications

### Архитектура уведомлений
- **Background Mode** - Remote notifications включен в Info.plist
- **Device Token** - автоматическая регистрация при авторизации
- **APNS токены** - синхронизация с сервером через API
- **Разрешения** - запрос только после авторизации пользователя

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

### Синхронизация токенов
Токены автоматически отправляются на сервер через PushNotificationMiddleware:
```swift
case .setAPNSToken(let token):
    if case .authenticated(let deviceId, _) = state.authState, token.isSynced == false {
        // Отправка токена на сервер через APIService
        // После успешной отправки: token.isSynced = true
    }
```

## Dependency Injection

### ServiceLocator
```swift
final class ServiceLocator {
    static let shared = ServiceLocator()
    
    func addService<T>(service: T)
    func getService<T>() -> T
}
```

### @Injected Property Wrapper
```swift
@propertyWrapper
struct Injected<Service> {
    private lazy var service: Service = ServiceLocator.shared.getService()
    public var wrappedValue: Service { service }
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

### Авторизация через Bearer токен
Все API запросы используют device_id в заголовке:
```swift
request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
```
### Если нужно, передаём язык приложения
```swift
    addLanguageHeaders(to: &request)
```


### Обработка ошибок
```swift
enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case httpError(Int)
    case serverError(String)
    case networkError(Error)
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
- Предупреждения и ошибки приложения через AppLogger

## Логирование

### AppLogger
```swift
struct AppLogger {
    static func info(_ message: String)              // Только в DEBUG
    static func warn(_ message: String)              // DEBUG + аналитика
    static func error(_ message: String, error: Error?) // DEBUG + аналитика
    static func action(_ action: AppAction)          // Redux actions в DEBUG
}
```

### Примеры логов
```
🎯 Action: setAuthState(authenticated("abc123def456", nil))
ℹ️ INFO: Got APNS token: 1234567890abcdef...
ℹ️ INFO: Apns token synced
⚠️ WARN: Migration retry attempt
❌ ERROR: APNS registration failed
```

## Конфигурация проекта

### Основные настройки
- **Bundle ID**: `ru.artembolotov.RedCalendar-Woman`
- **Display Name**: RedCalendar
- **Version**: 3.0
- **iOS Deployment Target**: 15.4+
- **Supported Devices**: iPhone только (портретная ориентация)

### Capabilities
- ✅ **Push Notifications** - для уведомлений
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

### Dependencies (Swift Package Manager)
- **AppMetrica SDK** v5.11.0 - аналитика Яндекса
  - AppMetricaCore
  - AppMetricaCrashes

## Workflow приложения

### Запуск приложения
1. **Configurator.setup()** - инициализация DI контейнера
2. **store.send(.setAuthState(nil))** - проверка авторизации
3. **AuthMiddleware** определяет текущее состояние:
   - device_id найден → `.authenticated`
   - только user_id → `.migrating`
   - ничего нет → `.notAuthenticated`

### Миграция с Firebase
1. Найден Firebase UID в keychain
2. MigrationMiddleware вызывает `APIService.migrateUser()`
3. Сервер возвращает новый device_id
4. device_id сохраняется в keychain, user_id удаляется
5. Переход в состояние `.authenticated`

### Push уведомления
1. При авторизации автоматически вызывается `registerForRemoteNotifications()`
2. AppDelegate получает токен и отправляет action `.setAPNSToken`
3. PushNotificationMiddleware синхронизирует токен с сервером
4. При успехе токен помечается как `isSynced: true`

### Retry механизм
При возвращении в активное состояние:
```swift
.onChange(of: scenePhase) { newPhase in
    if newPhase == .active {
        store.send(.setPushPermissionState(nil))  // Перепроверить разрешения
        store.send(.retryFailedTasks)             // Повторить неудачные операции
    }
}
```

## UI Архитектура

### RootView - роутинг
```swift
switch store.state.authState {
case nil:
    ProgressView("Проверка авторизации...")
case .notAuthenticated:
    LoginView()
case .migrating(let userId, let error):
    // UI миграции с обработкой ошибок и повтором
case .authenticated:
    HomeView()
}
```

### Состояние миграции
- **Без ошибки**: ProgressView с сообщением о переходе на новую систему
- **С ошибкой**: Показ ошибки и кнопка "Повторить"

### EnvironmentObject
Store передается через `@EnvironmentObject` во все дочерние View:
```swift
RootView()
    .environmentObject(store)
```

## Тестирование

### Проверка авторизации
Для тестирования используется тестовый Firebase UID:
```swift
Button("Войти (тест)") {
    store.send(.setAuthState(.migrating(
        userId: "nSJXOCPF3ocA4Znn1sL7KvI1dh13"))
    )
}
```

### Push Notifications
- **Симулятор**: APNS не работают, токен не приходит
- **Реальное устройство**: проверить получение токена в логах
- **Разрешения**: тестировать все сценарии (разрешить/запретить/настройки)

### Диагностика
```
// Redux actions
🎯 Action: setAuthState(migrating("nSJXOCPF3ocA4Znn1sL7KvI1dh13", nil))
🎯 Action: setAuthState(authenticated("abc123def456", nil))

// Push notifications  
ℹ️ INFO: Got APNS token: 1234567890abcdef...
ℹ️ INFO: Apns token synced

// Errors
❌ ERROR: Migration failed - Server error: User not found
⚠️ WARN: APNS token sync failed, will retry
```

## Безопасность

### Keychain
- **Accessibility**: `kSecAttrAccessibleAfterFirstUnlock`
- **Synchronizable**: `false` (не синхронизируется через iCloud)
- **Error handling**: подробное логирование ошибок keychain операций

### API Security
- **HTTPS only** - все запросы по защищенному соединению
- **Bearer Authentication** - device_id в заголовке Authorization
- **Device Model** - отправка модели устройства для аналитики
- **Error Handling** - безопасная обработка без раскрытия внутренней информации

### Приватность
- **No Data Collection** без согласия пользователя
- **Local Storage** - чувствительные данные только в Keychain
- **Analytics** - только технические события, никаких персональных данных

## Архитектурные решения

### Почему Redux?
- **Предсказуемость** - единое место для состояния приложения
- **Отладка** - логирование всех изменений состояния
- **Тестируемость** - чистые функции reducers легко тестировать
- **Асинхронность** - middleware для side effects и API вызовов

### Почему DI?
- **Тестируемость** - легко подменять зависимости в unit тестах
- **Слабая связанность** - компоненты не зависят от конкретных реализаций
- **Единая конфигурация** - все зависимости настраиваются в одном месте

### Почему SwiftUI?
- **Современность** - актуальный фреймворк от Apple
- **Декларативность** - описываем интерфейс через состояние
- **Производительность** - автоматическая оптимизация рендеринга
- **Реактивность** - идеальная интеграция с Redux через @EnvironmentObject

---

**Автор**: Артём Болотов  
**Версия**: 3.0  
**Последнее обновление**: 09.06.2025

## Изменения в версии 3.0

- ✅ Переход с UIKit на SwiftUI
- ✅ Реализация Redux архитектуры с middleware
- ✅ Автоматическая миграция с Firebase на собственную авторизацию
- ✅ Интеграция с собственным API сервером
- ✅ Push уведомления через APNs
- ✅ Аналитика через Яндекс AppMetrica
- ✅ Dependency Injection через ServiceLocator
- ✅ Безопасное хранение в Keychain
