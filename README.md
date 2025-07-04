# RedCalendar iOS 3.0

Современное iOS приложение для отслеживания менструального цикла, полностью переписанное на SwiftUI с Redux архитектурой. Проект мигрирован с Firebase на собственную российскую серверную инфраструктуру.

## 🎯 О проекте

RedCalendar переходит на собственную систему в связи с новыми требованиями российского законодательства, отказываясь от Firebase и Google сервисов в пользу отечественного хостинга NetAngels.

## 🏗 Архитектура

### Redux State Management
- **AppState** - глобальное состояние приложения
- **AppAction** - типизированные действия  
- **Middleware** - асинхронная логика и side effects
- **Store** - единый источник истины
- **Reducers** - pure functions для изменения состояния

### Dependency Injection
- **ServiceLocator** - DI контейнер для управления зависимостями
- **@Injected** - property wrapper для сервисов
- **Protocol-based** - слабые связи между компонентами

### SwiftUI + Combine
- **Декларативный UI** - описание интерфейса через состояние
- **@EnvironmentObject** - передача Store через иерархию
- **Reactive** - автоматические обновления при изменении состояния

## 🏛 Структура проекта

```
RedCalendar-Female/
├── App/                                    # Конфигурация приложения
│   ├── RedCalendar_FemaleApp.swift         # Main app entry point
│   ├── AppDelegate.swift                   # Push notifications
│   └── Configurator.swift                  # Настройка DI сервисов
├── Core/                                   # Ядро приложения
│   ├── DI/                                 # Dependency Injection
│   │   ├── ServiceLocator.swift            # DI контейнер
│   │   └── Injected.swift                  # Property wrapper
│   ├── Models/                             # Модели данных
│   │   ├── AuthState.swift                 # Состояния авторизации
│   │   ├── AuthenticationMethod.swift      # Методы авторизации
│   │   ├── EmailAuthState.swift            # Email auth состояния
│   │   ├── PhoneAuthState.swift            # Phone auth состояния
│   │   ├── AuthenticationError.swift       # Ошибки аутентификации
│   │   ├── APNSToken.swift                 # APNS токен модель
│   │   └── UserDetails.swift               # Данные пользователя
│   ├── Redux/                              # Redux архитектура
│   │   ├── Actions/
│   │   │   └── AppAction.swift             # Действия приложения
│   │   ├── States/
│   │   │   └── AppState.swift              # Глобальное состояние
│   │   ├── Store.swift                     # Store реализация
│   │   ├── AppStore.swift                  # Type alias для Store
│   │   ├── AppMiddleware.swift             # Комбинация middleware
│   │   ├── Middleware/                     # Middleware компоненты
│   │   │   ├── LoggerMiddleware.swift      # Логирование actions
│   │   │   ├── AuthMiddleware.swift        # Логика авторизации
│   │   │   ├── MigrationMiddleware.swift   # Миграция с Firebase
│   │   │   ├── PushNotificationsMiddleware.swift # Push уведомления
│   │   │   ├── AnalyticsMiddleware.swift   # Отправка событий
│   │   │   └── FeedbackMiddleware.swift    # Haptic feedback
│   │   └── Reducers/
│   │       └── AppReducer.swift            # Reducer функции
│   ├── Services/                           # Сервисы приложения
│   │   ├── APIService.swift                # HTTP клиент
│   │   ├── KeychainService.swift           # Secure storage
│   │   ├── AnalyticsService.swift          # AppMetrica integration
│   │   ├── PushPermissionService.swift     # Push notifications
│   │   └── TapticFeedbackService.swift     # Haptic feedback
│   └── Extensions/                         # Расширения
│       └── AppLogger.swift                 # Логирование
├── Features/                               # Функциональные модули
│   ├── Auth/                               # Модуль авторизации
│   │   ├── Views/
│   │   │   ├── LoginView.swift             # Координатор auth views
│   │   │   ├── WelcomeView.swift           # Стартовый экран
│   │   │   ├── EmailAuth/
│   │   │   │   ├── EmailEntryView.swift    # Ввод email
│   │   │   │   └── CodeEntryView.swift     # Ввод кода подтверждения
│   │   │   └── PhoneAuth/
│   │   │       ├── PhoneEntryView.swift    # Ввод номера телефона
│   │   │       └── FlashCallCodeEntryView.swift # Flash Call верификация
│   │   └── Components/
│   │       ├── PrimaryButton.swift         # Основная кнопка
│   │       ├── FormFieldStyle.swift        # Стиль полей ввода
│   │       └── WaitingView.swift           # Loading состояния
│   └── Main/                               # Основной функционал
│       └── MainView.swift                  # Главный экран (placeholder)
└── Resources/                              # Ресурсы
    ├── Assets.xcassets                     # Изображения и цвета
    ├── Localizable.strings                 # Локализация
    └── Info.plist                          # Конфигурация приложения
```

## 📱 Функциональность

### ✅ Реализовано

**Система авторизации:**
- ✅ Email авторизация с валидацией и автозаполнением
- ✅ Flash Call авторизация для пользователей версии 2.0 (**NEW**)
- ✅ Детальные состояния для каждого шага процесса
- ✅ Миграция с Firebase UID → device_id
- ✅ Обработка ошибок на каждом этапе с понятными сообщениями
- ✅ Единая модель UserDetails для всех методов auth (**NEW**)

**Пользовательский интерфейс:**
- ✅ Экран приветствия с онбордингом (4 слайда)
- ✅ Адаптивная верстка (max width 320pt для форм)
- ✅ Автофокус на полях ввода с плавными переходами
- ✅ Email suggestions и умное автозаполнение
- ✅ Поддержка markdown ссылок в тексте
- ✅ Единообразный дизайн-язык на всех экранах

**Push уведомления:**
- ✅ Автоматическая регистрация APNS токенов
- ✅ Синхронизация с сервером через middleware
- ✅ Background refresh для обновления токенов

**Haptic Feedback система:**
- ✅ TapticFeedbackService для управления тактильной обратной связью
- ✅ FeedbackMiddleware для интеграции в Redux
- ✅ Success/Error/Prepare feedback для ключевых событий

### 🔄 В разработке
- 🔄 Основные экраны календаря и трекинга
- 🔄 CRUD операции для пользовательских данных
- 🔄 Расширение Haptic Feedback для всех UI взаимодействий

## 🔐 Authentication Architecture

### Flash Call Authentication Flow (**NEW**)

#### Архитектура компонентов

```
FlashCallCodeEntryView
├── получает данные из Redux state
├── отображает UI для ввода кода
├── валидирует 4-значный код
└── отправляет actions в AuthMiddleware

AuthMiddleware
├── обрабатывает phone auth states
├── вызывает APIService методы
├── управляет переходами между состояниями
└── обрабатывает ошибки

APIService
├── checkPhone() - инициация Flash Call
├── verifyFlashCall() - верификация кода
└── единая структура ответов
```

#### Phone Auth States

```swift
enum PhoneAuthState {
    case entry(
        prettyPhoneNumber: String? = nil,
        error: AuthenticationError? = nil
    )
    case requesting(
        prettyPhoneNumber: String,
        e164PhoneNumber: String
    )
    case verification(
        prettyPhoneNumber: String,
        e164PhoneNumber: String,
        maskedCallerNumber: String,
        requestId: String,           // NEW: для верификации
        error: AuthenticationError? = nil
    )
    case verifying(
        prettyPhoneNumber: String,
        e164PhoneNumber: String,
        requestId: String,           // NEW: для верификации
        verificationCode: String
    )
}
```

#### Полный Flow Flash Call Auth

1. **Phone Entry** (`PhoneEntryView`) → Ввод номера телефона
2. **API Request** (`AuthMiddleware`) → Запрос Flash Call через checkPhone()
3. **Code Entry** (`FlashCallCodeEntryView`) → Ввод 4-значного кода
4. **Verification** (`AuthMiddleware`) → Верификация через verifyFlashCall()
5. **Success** → Переход в authenticated состояние с UserDetails

### Email Authentication Flow

#### Email Auth States

```swift
enum EmailAuthState {
    case entry(email: String? = nil, error: Error? = nil)
    case checking(email: String, name: String? = nil)
    case codeEntry(email: String, code: String? = nil, userName: String? = nil, error: AuthenticationError? = nil)
    case verifying(email: String, code: String, name: String? = nil)
    case registration(email: String, code: String? = nil, name: String? = nil, error: AuthenticationError? = nil)
    case registering(email: String, code: String, name: String?)
}
```

### Унифицированная модель UserDetails (**NEW**)

```swift
struct UserDetails: Codable {
    let userId: String          // Firebase UID - основной идентификатор
    let name: String?           // Имя пользователя
    let email: String?          // Email пользователя  
    let settings: UserSettings? // JSONB настройки из базы
    
    // Computed property для API совместимости
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "id"
        case name
        case email
        case settings
    }
}

struct UserSettings: Codable {
    let cycle: CycleSettings?
    let predictions: PredictionSettings?
    let notifications: NotificationSettings?
    
    struct CycleSettings: Codable {
        let defaultLength: Int?
        let defaultPeriodLength: Int?
        let lutealPhaseLength: Int?
    }
    
    struct PredictionSettings: Codable {
        let enablePeriod: Bool?
        let enableFertile: Bool?
    }
    
    struct NotificationSettings: Codable {
        let muted: Bool?
    }
}
```

#### Преимущества унификации

- ✅ **Email и Phone auth** возвращают идентичную структуру user
- ✅ **Единая модель** для всего приложения
- ✅ **Простота использования** в UI компонентах
- ✅ **Расширяемость** - легко добавить новые поля

## 🔄 API Integration

### APIService методы

```swift
protocol APIServiceProtocol {
    // Email auth
    func checkEmail(_ email: String) async throws -> CheckEmailResponse
    func verifyCode(email: String, code: String, name: String?) async throws -> VerifyCodeResponse
    
    // Phone auth  
    func checkPhone(_ phone: String) async throws -> CheckPhoneResponse
    func verifyFlashCall(requestId: String, code: String) async throws -> VerifyFlashCallResponse
    
    // Device management
    func verifyDevice(deviceId: String) async throws -> VerificationResponse
    func updateAPNSToken(deviceId: String, apnsToken: String) async throws -> APNSTokenResponse
    func logout(deviceId: String) async throws -> LogoutResponse
}
```

### Единая структура ответов (**NEW**)

Все методы аутентификации возвращают унифицированную структуру:

```json
{
  "success": true,
  "data": {
    "device_id": "generated_device_id",
    "user": {
      "id": "firebase_uid",
      "name": "Имя пользователя",
      "email": "user@example.com",
      "settings": {
        "cycle": {"default_length": 28, "default_period_length": 5, "luteal_phase_length": 14},
        "predictions": {"enable_period": true, "enable_fertile": true},
        "notifications": {"muted": false}
      }
    }
  },
  "message": "Success message",
  "timestamp": "2025-07-03T12:34:56.789Z"
}
```

## 🧩 UI Components

### FlashCallCodeEntryView (**NEW**)

Специализированный компонент для Flash Call верификации:

```swift
struct FlashCallCodeEntryView: View {
    @EnvironmentObject var store: AppStore
    @State private var codeInput: String = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    // Автоматически получает данные из state
    var body: some View {
        switch store.state.authState {
        case .authenticating(.phone(.verification(let prettyPhoneNumber, let e164PhoneNumber, 
                                                  let maskedCallerNumber, let requestId, let error))):
            // Отображает UI с всеми необходимыми данными
        }
    }
}
```

**Возможности:**
- ✅ Автоматическое получение данных из Redux state
- ✅ Валидация 4-значного кода (только цифры)
- ✅ Отображение замаскированного номера звонящего
- ✅ Обработка ошибок с локализованными сообщениями
- ✅ Автофокус на поле ввода
- ✅ Переход назад к вводу номера
- ✅ Запрос нового звонка

### Переиспользуемые компоненты

```swift
// Основная кнопка с состояниями
PrimaryButton("Войти", isEnabled: isFormValid, action: submitAction)

// Стиль полей ввода
TextField("Email", text: $email).formFieldStyle()

// Loading состояния
WaitingView("Отправляем код")
```

## ⚠️ Error Handling

### AuthenticationError для Flash Call

```swift
enum AuthenticationError: Error, LocalizedError {
    // Phone errors
    case phoneNotRegistered        // Номер не найден в RedCalendar 2.0
    case phoneCallFailed          // Flash Call не удался
    case phoneVerificationFailed  // Неверный код верификации
    case phoneCallTimeout         // Звонок не пришел
    
    // Email errors
    case emailNotFound            // Email не найден
    case invalidVerificationCode  // Неверный код подтверждения
    case verificationCodeExpired  // Код истек
    
    var errorDescription: String? {
        switch self {
        case .phoneNotRegistered:
            return "Этот номер не найден в RedCalendar 2.0. Используйте вход через email."
        case .phoneCallFailed:
            return "Не удалось инициировать звонок. Попробуйте еще раз."
        case .phoneVerificationFailed:
            return "Неверный код. Попробуйте еще раз."
        case .phoneCallTimeout:
            return "Звонок не пришел. Запросите новый звонок."
        }
    }
}
```

## 🧪 Testing & Development

### Preview данные
```swift
#Preview("Flash Call Code Entry") {
    FlashCallCodeEntryView()
        .environmentObject(mockStoreWithFlashCallState)
}

#Preview("Email Code Entry") {
    CodeEntryView()
        .environmentObject(mockStoreWithEmailState)
}
```

### Тестирование в симуляторе
- Email auth: используйте тестовые коды из логов сервера
- Flash Call: доступно только на staging с тестовыми номерами

## 🔧 Последние изменения

### **Июль 2025 - Flash Call Authentication (**NEW**)**

**Новые файлы:**
- `FlashCallCodeEntryView.swift` - UI для Flash Call верификации
- `PhoneAuthState.swift` - состояния телефонной аутентификации
- Обновленный `UserDetails.swift` - унифицированная модель пользователя

**Изменения:**
- Расширен `AuthMiddleware` для обработки phone auth
- Добавлены методы `checkPhone` и `verifyFlashCall` в `APIService`
- Унифицированы все API response models
- Обновлен `LoginView` для поддержки Flash Call flow

**API интеграция:**
- Единая структура user данных для всех методов auth
- requestId tracking для Flash Call сессий
- Правильная обработка ошибок и состояний

### **16.06.2025 - Haptic Feedback система**

**Новые файлы:**
- `TapticFeedbackService.swift` - сервис для управления тактильной обратной связью
- `FeedbackMiddleware.swift` - middleware для интеграции haptic feedback в Redux

**Изменения:**
- Добавлена регистрация TapticFeedbackService в `Configurator.swift`
- Интеграция haptic events в ключевые моменты пользовательского опыта
- Success feedback при успешной авторизации
- Prepare feedback generators для оптимальной производительности

## 🚀 Setup & Development

### Требования
- iOS 15.4+
- Xcode 16.4+
- Swift 5.9+

### Установка
1. Клонировать репозиторий с GitHub
2. Открыть `RedCalendar-Female.xcodeproj` в Xcode
3. Настроить Bundle Identifier и команду разработчика
4. Настроить push notifications в Apple Developer Portal
5. Убедиться что все сервисы зарегистрированы в DI контейнере

### Зависимости
Проект использует Swift Package Manager:
- **AppMetrica** - аналитика и мониторинг
  - AppMetricaCore
  - AppMetricaCrashes

## 📈 Roadmap

### Версия 3.1 (Текущая) ✅
- ✅ Базовая Redux архитектура
- ✅ Email и Flash Call авторизация
- ✅ Push notifications через APNs
- ✅ Унифицированная модель UserDetails
- ✅ Haptic Feedback система

### Версия 3.2 (В разработке) 🔄
- 🔄 Основные экраны календаря и трекинга
- 🔄 CRUD операции для пользовательских данных
- 🔄 Offline поддержка с синхронизацией

### Версия 3.3 (Планируется) 📋
- 📋 Продвинутая аналитика и мониторинг
- 📋 Comprehensive unit и UI тестирование
- 📋 Локализация на дополнительные языки

## 🤝 Команда

**Разработчик:** Артём Болотов  
**Frontend:** SwiftUI + Redux архитектура  
**Backend:** Node.js API на NetAngels  
**Аналитика:** AppMetrica  

---

**Версия 3.1** - Июль 2025  
**Flash Call Integration** - Июль 2025  
**Haptic Feedback** - Июнь 2025Id,
                error: error
            )
        default:
            EmptyView()
        }
    }
}
```

#### Основные возможности:
- ✅ **Автоматическое получение данных** из Redux state
- ✅ **Валидация 4-значного кода** только цифры
- ✅ **Отображение номера звонящего** замаскированного
- ✅ **Обработка ошибок** с локализованными сообщениями
- ✅ **Автофокус** на поле ввода
- ✅ **Переход назад** к вводу номера
- ✅ **Запрос нового звонка** через Redux action

### LoginView Integration

```swift
// MARK: - Phone Auth Views
@ViewBuilder
private func phoneAuthView(for state: PhoneAuthState) -> some View {
    switch state {
    case .entry(_, _):
        PhoneEntryView()
    case .requesting(_, _):
        WaitingView("Проверяем номер")
    case .verification(_, _, _, _, _):
        FlashCallCodeEntryView()  // ← Автоматически получает все данные из state
    case .verifying(_, _, _, _):
        WaitingView("Проверяем код")
    }
}
```

## Error Handling

### AuthenticationError для Flash Call

```swift
enum AuthenticationError: Error, LocalizedError {
    // Phone errors
    case phoneNotRegistered        // Номер не найден в RedCalendar 2.0
    case phoneCallFailed          // Flash Call не удался
    case phoneVerificationFailed  // Неверный код верификации
    case phoneCallTimeout         // Звонок не пришел
    
    // ... другие ошибки
    
    var errorDescription: String? {
        switch self {
        case .phoneNotRegistered:
            return "Этот номер не найден в RedCalendar 2.0. Используйте вход через email."
        case .phoneCallFailed:
            return "Не удалось инициировать звонок. Попробуйте еще раз."
        case .phoneVerificationFailed:
            return "Неверный код. Попробуйте еще раз."
        case .phoneCallTimeout:
            return "Звонок не пришел. Запросите новый звонок."
        }
    }
}
```

## Redux State Management

### AuthMiddleware обновления

#### Phone Authentication Logic:
```swift
case .requesting(let prettyPhoneNumber, let e164PhoneNumber):
    Task {
        do {
            let response = try await apiService.checkPhone(e164PhoneNumber)
            
            guard let data = response.data else {
                throw APIServiceError.serverError("No data received")
            }
            
            if response.success && data.exists {
                // Flash Call успешно инициирован
                guard let flashCall = data.flashCall else {
                    throw APIServiceError.serverError("Flash Call data missing")
                }
                
                phoneState = .verification(
                    prettyPhoneNumber: prettyPhoneNumber,
                    e164PhoneNumber: e164PhoneNumber,
                    maskedCallerNumber: flashCall.from,
                    requestId: flashCall.requestId,
                    error: nil
                )
            } else {
                // Ошибка - номер не найден или Flash Call не удался
                let authError: AuthenticationError = !data.exists 
                    ? .phoneNotRegistered 
                    : .phoneCallFailed
                    
                phoneState = .entry(
                    prettyPhoneNumber: prettyPhoneNumber,
                    error: authError
                )
            }
        } catch {
            phoneState = .entry(
                prettyPhoneNumber: prettyPhoneNumber,
                error: AuthenticationError.from(error)
            )
        }
        
        dispatch(.setAuthState(.authenticating(.phone(phoneState))))
    }

case .verifying(let prettyPhoneNumber, let e164PhoneNumber, let requestId, let verificationCode):
    Task {
        do {
            let response = try await apiService.verifyFlashCall(requestId: requestId, code: verificationCode)
            
            guard response.success, let data = response.data else {
                throw APIServiceError.serverError("Flash Call verification failed")
            }
            
            // Сохранить device ID и перейти в authenticated состояние
            keychain.saveDeviceID(data.deviceId)
            keychain.deleteUserUID()
            
            dispatch(.setAuthState(.authenticated(
                deviceId: data.deviceId,
                userDetails: data.user  // ← Полные данные пользователя
            )))
            
        } catch {
            let phoneState: PhoneAuthState = .entry(
                prettyPhoneNumber: prettyPhoneNumber,
                error: AuthenticationError.from(error)
            )
            
            dispatch(.setAuthState(.authenticating(.phone(phoneState))))
        }
    }
```

## Testing & Development

### Preview данные
```swift
#Preview("Flash Call Code Entry") {
    FlashCallCodeEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.phone(.verification(
                        prettyPhoneNumber: "+7 (999) 123-45-67",
                        e164PhoneNumber: "+79991234567",
                        maskedCallerNumber: "+33700001234",
                        requestId: "fp9RPWDGZkskBrVeTc4lgNCc4e79fc65",
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
```

### Тестирование в симуляторе
```swift
// Для тестирования можно использовать моковые данные:
// 1. Установить состояние verification вручную
// 2. Ввести тестовый код (например "1234")
// 3. Проверить переход в authenticated состояние
```

## Migration Notes

### Изменения относительно предыдущих версий:

#### ✅ **Добавлено:**
- Flash Call authentication flow
- `requestId` в Phone auth states
- Унифицированная модель UserDetails
- `verifyFlashCall` метод в APIService
- FlashCallCodeEntryView компонент

#### 🔄 **Изменено:**
- UserDetails расширен новыми полями
- PhoneAuthState структура обновлена
- AuthMiddleware логика для phone auth
- API response models унифицированы

#### ❌ **Удалено:**
- Отдельные UserInfo модели в API responses
- `user_id`, `is_new_user` поля из ответов

---

**Архитектура готова к использованию!** 🚀  
Все компоненты интегрированы и протестированы.
