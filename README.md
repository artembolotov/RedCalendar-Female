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
│   │   ├── AuthState.swift           # Состояния авторизации
│   │   ├── AuthenticationMethod.swift # Методы авторизации (phone/email)
│   │   ├── PhoneAuthState.swift      # Состояния телефонной авторизации
│   │   ├── EmailAuthState.swift      # Состояния email авторизации
│   │   ├── AuthenticationError.swift # Ошибки авторизации
│   │   ├── APNSToken.swift           # APNS токен
│   │   └── UserDetails.swift         # Данные пользователя
│   ├── DI/                       # Dependency Injection
│   │   ├── ServiceLocator.swift  # DI контейнер
│   │   └── Injected.swift        # Property wrapper
│   └── Utils/                    # Утилиты
│       └── Logger.swift          # Система логирования
├── Features/                     # UI экраны
│   ├── Auth/Views/               # Авторизация
│   │   ├── LoginView.swift       # Экран выбора метода входа
│   │   ├── PhoneAuthView.swift   # Авторизация по телефону
│   │   └── EmailAuthView.swift   # Авторизация по email
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
    case checkAuthState
    case setAuthState(_ state: AuthState)
    case logout
    
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

## Система авторизации

### AuthState - основные состояния
```swift
enum AuthState {
    case authenticating(AuthenticationMethod?)       // nil = not authenticated, show login screen
    case authenticated(deviceId: String, userDetails: UserDetails?)
    case migrating(userId: String, error: Error? = nil)
}
```

### AuthenticationMethod - методы входа
```swift
enum AuthenticationMethod {
    case phone(PhoneAuthState)
    case email(EmailAuthState)
}
```

### Телефонная авторизация
```swift
enum PhoneAuthState {
    case entry                                        // Enter phone number
    case requesting(phoneNumber: String)              // Requesting flash call
    case verification(                               // Waiting for call verification
        phoneNumber: String,
        maskedCallerNumber: String,                  // e.g., "+7 XXX XXX XX34"
        error: AuthenticationError? = nil
    )
    case verifying(                                  // Verifying entered digits
        phoneNumber: String,
        verificationCode: String
    )
}
```

**Поток телефонной авторизации:**
1. **Ввод номера** - пользователь вводит номер телефона
2. **Запрос звонка** - система запрашивает flash call у сервера
3. **Ожидание звонка** - показ маски номера и инструкций
4. **Ввод кода** - пользователь вводит последние цифры номера
5. **Проверка кода** - отправка на сервер для верификации
6. **Успех** - переход в состояние `authenticated`

### Email авторизация
```swift
enum EmailAuthState {
    case entry                                       // Enter email address
    case checking(email: String)                     // Checking if email exists
    case passwordEntry(                             // Enter password for existing user
        email: String,
        userName: String,
        error: AuthenticationError? = nil
    )
    case passwordVerifying(                         // Verifying email + password
        email: String,
        password: String
    )
    case registration(                              // New user registration flow
        email: String,
        step: RegistrationStep
    )
    case passwordRecovery(                          // Forgot password flow
        email: String,
        step: PasswordRecoveryStep
    )
}
```

**Поток email авторизации (существующий пользователь):**
1. **Ввод email** - пользователь вводит адрес электронной почты
2. **Проверка email** - система проверяет существование в базе
3. **Ввод пароля** - если найден, показ формы пароля с именем пользователя
4. **Проверка пароля** - отправка email+пароль на сервер
5. **Успех** - переход в состояние `authenticated`

### Регистрация новых пользователей
```swift
enum RegistrationStep {
    case userDataEntry                              // Enter name and create password (combined screen)
    case creating(                                  // Creating account on server
        name: String,
        password: String
    )
    case emailVerification(verificationCode: String?) // Verify email with code
    case verifyingEmail(                           // Verifying email code on server
        verificationCode: String
    )
}
```

**Поток регистрации:**
1. **Ввод данных** - имя и пароль на одном экране
2. **Создание аккаунта** - отправка данных на сервер
3. **Подтверждение email** - ввод 6-значного кода из письма
4. **Проверка кода** - верификация кода на сервере
5. **Успех** - переход в состояние `authenticated`

### Восстановление пароля
```swift
enum PasswordRecoveryStep {
    case codeRequesting                            // Requesting verification code
    case codeVerification(error: AuthenticationError? = nil) // Enter 6-digit code
    case verifyingCode(code: String)               // Verifying code on server
    case passwordReset                             // Enter new password + confirmation
    case resettingPassword(                        // Resetting password on server
        newPassword: String,
        confirmPassword: String
    )
}
```

**Поток восстановления пароля:**
1. **Запрос кода** - отправка кода восстановления на email
2. **Ввод кода** - пользователь вводит полученный код
3. **Проверка кода** - верификация на сервере
4. **Новый пароль** - ввод нового пароля и подтверждения
5. **Смена пароля** - обновление пароля на сервере
6. **Успех** - переход в состояние `authenticated`

### Обработка ошибок
```swift
enum AuthenticationError: Error, LocalizedError {
    // Phone errors
    case phoneNotRegistered                        // Not a RedCalendar 2.0 user
    case phoneCallFailed                          // Flash call request failed
    case phoneVerificationFailed                  // Wrong verification digits
    case phoneCallTimeout                         // Call didn't arrive
    
    // Email errors
    case emailNotFound                            // Email doesn't exist (new user)
    case emailAlreadyExists                       // Email taken during registration
    case invalidPassword                          // Wrong password
    case weakPassword                             // Password doesn't meet requirements
    case passwordMismatch                         // Password confirmation doesn't match
    
    // Code verification errors
    case invalidVerificationCode                  // Wrong 6-digit code
    case verificationCodeExpired                  // Code expired
    case verificationCodeLimitExceeded            // Too many attempts
    
    // Registration errors
    case registrationFailed                       // Account creation failed
    case nameRequired                            // Name field is empty
    case emailVerificationFailed                 // Email verification failed
    
    // Network/Server errors
    case networkError(Error)                      // Network connectivity issues
    case serverError(String)                      // Server-side errors
    case unknownError                             // Fallback error
}
```

## Миграция с Firebase

### Логика миграции
Приложение автоматически мигрирует пользователей с Firebase Auth на собственную систему:

```swift
// Логика в AuthMiddleware
case .checkAuthState:
    // Приоритет 1: Ищем device_id (новая система)
    if let deviceId = keychain.getDeviceID() {
        return [.setAuthState(.authenticated(deviceId: deviceId, userDetails: nil))]
    }
    
    // Приоритет 2: Ищем legacy user_id (Firebase)
    if let userId = keychain.getUserUID() {
        return [.setAuthState(.migrating(userId: userId, error: nil))]
    }
    
    // Нет учетных данных
    return [.setAuthState(.authenticating(nil))]
```

### Состояния миграции
```swift
case migrating(userId: String, error: Error? = nil)
```

**Поток миграции:**
1. Найден Firebase UID в keychain
2. MigrationMiddleware вызывает `APIService.migrateUser()`
3. Сервер возвращает новый device_id
4. device_id сохраняется в keychain, user_id удаляется
5. Переход в состояние `.authenticated`

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
    func logout(deviceId: String) async throws -> LogoutResponse
    
    // New authentication methods
    func checkEmail(email: String) async throws -> EmailCheckResponse
    func signInWithPassword(email: String, password: String) async throws -> SignInResponse
    func registerUser(email: String, name: String, password: String) async throws -> RegistrationResponse
    func requestPhoneCall(phoneNumber: String) async throws -> PhoneCallResponse
    func verifyPhoneCall(phoneNumber: String, code: String) async throws -> PhoneVerificationResponse
    func requestPasswordReset(email: String) async throws -> PasswordResetResponse
    func verifyResetCode(email: String, code: String) async throws -> CodeVerificationResponse
    func resetPassword(email: String, code: String, newPassword: String) async throws -> PasswordResetResponse
}
```

### Авторизация через Bearer токен
Все API запросы используют device_id в заголовке:
```swift
request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
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
    case unauthorized
}
```

## UI Архитектура

### RootView - роутинг
```swift
switch store.state.authState {
case nil:
    ProgressView("Проверка авторизации...")
case .authenticating(nil):
    LoginView()  // Show login method selection
case .authenticating(.phone(let phoneState)):
    PhoneAuthView(state: phoneState)
case .authenticating(.email(let emailState)):
    EmailAuthView(state: emailState)
case .authenticated:
    HomeView()
case .migrating(let userId, let migrationError):
    // Migration UI with error handling and retry
}
```

### Экраны авторизации

**LoginView** - выбор метода входа:
- Поле для ввода email + кнопка "Продолжить"
- Кнопка "Вход по номеру телефона" (для пользователей RedCalendar 2.0)

**PhoneAuthView** - авторизация по телефону:
- `.entry` - ввод номера телефона
- `.requesting` - загрузка (запрос звонка)
- `.verification` - ожидание звонка, показ маски номера, ввод кода
- `.verifying` - загрузка (проверка кода)

**EmailAuthView** - авторизация по email:
- `.entry` - ввод email
- `.checking` - загрузка (проверка email)
- `.passwordEntry` - ввод пароля для существующего пользователя
- `.passwordVerifying` - загрузка (проверка пароля)
- `.registration` - регистрация нового пользователя
- `.passwordRecovery` - восстановление пароля

### EnvironmentObject
Store передается через `@EnvironmentObject` во все дочерние View:
```swift
RootView()
    .environmentObject(store)
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
- Выбор метода авторизации (phone/email)
- Ошибки авторизации и регистрации
- Успешные авторизации и регистрации
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
🎯 Action: setAuthState(authenticating(.email(.entry)))
🎯 Action: setAuthState(authenticated("abc123def456", nil))
ℹ️ INFO: Got APNS token: 1234567890abcdef...
ℹ️ INFO: Apns token synced
⚠️ WARN: Migration retry attempt
❌ ERROR: Phone verification failed
❌ ERROR: Invalid password
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
2. **store.send(.checkAuthState)** - проверка авторизации
3. **AuthMiddleware** определяет текущее состояние:
   - device_id найден → `.authenticated`
   - только user_id → `.migrating`
   - ничего нет → `.authenticating(nil)`

### Новая авторизация
1. Пользователь в состоянии `.authenticating(nil)` видит экран выбора метода
2. Выбирает email или телефон → переход в `.authenticating(.email/.phone)`
3. Проходит соответствующий поток авторизации
4. При успехе → `.authenticated(deviceId, userDetails)`

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

### Авторизация
- **Email flow**: тестировать существующих и новых пользователей
- **Phone flow**: тестировать с пользователями RedCalendar 2.0
- **Error handling**: проверить все типы ошибок
- **Loading states**: убедиться что показываются индикаторы загрузки

### Диагностика
```
// Redux actions
🎯 Action: setAuthState(authenticating(.email(.checking("user@example.com"))))
🎯 Action: setAuthState(authenticating(.email(.passwordEntry("user@example.com", "John"))))
🎯 Action: setAuthState(authenticated("abc123def456", nil))

// Push notifications  
ℹ️ INFO: Got APNS token: 1234567890abcdef...
ℹ️ INFO: Apns token synced

// Authentication errors
❌ ERROR: Email check failed - Network error
❌ ERROR: Password verification failed - Invalid password
⚠️ WARN: Phone verification failed, retrying
```

## Безопасность

### Keychain
- **Accessibility**: `kSecAttrAccessibleAfterFirstUnlock`
- **Synchronizable**: `false` (не синхронизируется через iCloud)
- **Error handling**: подробное логирование ошибок keychain операций

### API Security
- **HTTPS only** - все запросы по защищенному соединению
- **Bearer Authentication** - device_id в заголовке Authorization
- **Password validation** - проверка сложности пароля на клиенте и сервере
- **Rate limiting** - защита от брутфорса через ограничения API
- **Device Model** - отправка модели устройства для аналитики
- **Error Handling** - безопасная обработка без раскрытия внутренней информации

### Приватность
- **No Data Collection** без согласия пользователя
- **Local Storage** - чувствительные данные только в Keychain
- **Analytics** - только технические события, никаких персональных данных
- **Password Security** - пароли никогда не сохраняются локально

## Архитектурные решения

### Почему Redux?
- **Предсказуемость** - единое место для состояния приложения
- **Отладка** - логирование всех изменений состояния
- **Тестируемость** - чистые функции reducers легко тестировать
- **Асинхронность** - middleware для side effects и API вызовов
- **Сложные состояния** - элегантная обработка многоэтапных процессов авторизации

### Почему вложенные enums для AuthState?
- **Type Safety** - компилятор проверяет все возможные состояния
- **Четкая структура** - каждый метод авторизации изолирован
- **Легкое расширение** - добавление новых методов без изменения существующего кода
- **Детальные состояния** - точное отражение каждого шага процесса
- **Обработка ошибок** - ошибки привязаны к конкретным состояниям

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
**Версия**: 3.1  
**Последнее обновление**: 12.06.2025

## Изменения в версии 3.1

- ✅ Добавлена полноценная система авторизации с email и телефоном
- ✅ Реализованы детальные состояния для каждого шага авторизации
- ✅ Добавлена регистрация новых пользователей через email
- ✅ Реализовано восстановление пароля через email код
- ✅ Добавлена авторизация по телефону для пользователей RedCalendar 2.0
- ✅ Упрощена структура AuthState (убран notAuthenticated)
- ✅ Добавлены промежуточные состояния для всех API вызовов
- ✅ Реализована комплексная обработка ошибок авторизации
- ✅ Подготовлена архитектура для UI экранов авторизации
- ✅ Расширена аналитика для отслеживания событий авторизации
