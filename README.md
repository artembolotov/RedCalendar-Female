# RedCalendar iOS 3.0

Современное iOS приложение для отслеживания менструального цикла, полностью переписанное на SwiftUI с Redux архитектурой.

## 🏗 Архитектура

### Redux State Management
- **AppState** - глобальное состояние приложения
- **AppAction** - типизированные действия
- **Middleware** - асинхронная логика и side effects
- **Store** - единый источник истины

### Dependency Injection
- **ServiceLocator** - DI контейнер
- **@Injected** - property wrapper для сервисов
- **Protocol-based** - слабые связи между компонентами

### SwiftUI + Combine
- **Декларативный UI** - описание через состояние
- **@EnvironmentObject** - передача Store через иерархию
- **Reactive** - автоматические обновления при изменении состояния

## 📱 Функциональность

### ✅ Реализовано

**Система авторизации:**
- Email авторизация с валидацией
- Телефонная авторизация для пользователей 2.0
- Детальные состояния для каждого шага
- Миграция с Firebase UID → device_id
- Обработка ошибок на каждом этапе

**Пользовательский интерфейс:**
- Экран приветствия с онбордингом (4 слайда)
- Адаптивная верстка (320pt max width для форм)
- Автофокус на полях ввода
- Email suggestions и автозаполнение
- Markdown ссылки в тексте
- Единообразный дизайн на всех экранах

**Push уведомления:**
- Автоматическая регистрация APNS токенов
- Синхронизация с сервером
- Retry механизм при сбоях
- Очистка badge при активации

**Haptic Feedback:**
- TapticFeedbackService для тактильной обратной связи
- Поддержка success, error, warning событий
- Интеграция через FeedbackMiddleware
- Подготовка генераторов для оптимальной производительности

**Техническая часть:**
- Keychain для безопасного хранения
- AppMetrica аналитика
- Логирование действий и ошибок
- Graceful обработка сетевых ошибок

### 🔄 В разработке

**Email/Phone авторизация:**
- Проверка существования email
- Экраны ввода пароля и регистрации
- Восстановление пароля
- Верификация телефонного номера

**Основной функционал:**
- CRUD операции для циклов
- Трекинг симптомов и настроения
- Календарь с предсказаниями
- Комментарии и пользовательские теги

**API интеграция:**
- Синхронизация данных с сервером
- Offline поддержка
- Конфликт resolution

## 🎨 UI/UX

### Дизайн-система
- **Максимальная ширина форм:** 320pt для оптимальной читаемости
- **Отступы:** стандартные 16pt по краям
- **Цветовая схема:** красно-розовые градиенты
- **Типографика:** SF Pro с семантическими размерами

### Адаптивность
- **iPhone:** полноэкранный режим
- **iPad:** центрированный контент с ограничением ширины
- **Альбомная ориентация:** сохранение пропорций
- **Accessibility:** поддержка screen readers

### Анимации
- **Page transitions:** плавные переходы между слайдами
- **Loading states:** индикаторы прогресса
- **Focus management:** автоматическая навигация по полям
- **Error feedback:** визуальные индикаторы ошибок
- **Haptic feedback:** тактильная обратная связь для ключевых событий

## 🔐 Безопасность

### Данные пользователя
- **Keychain Storage** - device_id и чувствительные данные
- **No localStorage** - все в памяти или Keychain
- **HTTPS only** - защищенные соединения
- **Bearer tokens** - device_id в заголовках

### Приватность
- **Local-first** - данные хранятся локально и в облаке
- **No tracking** - только техническая аналитика
- **Encrypted transport** - все запросы зашифрованы
- **User control** - полный контроль над данными

## 📋 Модели данных

### AuthState - Состояния авторизации
```swift
enum AuthState {
    case notAuthenticated
    case authenticated(deviceId: String, userDetails: UserDetails?)
    case migrating(userId: String, error: Error? = nil)
    case authenticating(AuthenticationMethod)
}

enum AuthenticationMethod {
    case phone(PhoneAuthState)
    case email(EmailAuthState)
}
```

### EmailAuthState - Email авторизация
```swift
enum EmailAuthState {
    case entry(email: String? = nil, error: Error? = nil)
    case checking(email: String)
    case passwordEntry(email: String, userName: String, error: AuthenticationError? = nil)
    case passwordVerifying(email: String, password: String)
    case registration(email: String, step: RegistrationStep)
    case passwordRecovery(email: String, step: PasswordRecoveryStep)
}
```

### PhoneAuthState - Телефонная авторизация
```swift
enum PhoneAuthState {
    case entry
    case requesting(phoneNumber: String)
    case verification(phoneNumber: String, maskedCallerNumber: String, error: AuthenticationError? = nil)
    case verifying(phoneNumber: String, verificationCode: String)
}
```

## 🏛 Структура проекта

```
RedCalendar-Female/
├── Core/                                   # Ядро приложения
│   ├── Redux/                              # Redux архитектура
│   │   ├── AppState.swift                  # Глобальное состояние
│   │   ├── AppAction.swift                 # Действия приложения
│   │   ├── Store.swift                     # Store реализация
│   │   ├── AppStore.swift                  # Type alias для Store
│   │   ├── AppMiddleware.swift             # Комбинация middleware
│   │   └── Reducers/
│   │       └── AppReducer.swift            # Reducer функции
│   ├── Middleware/                         # Асинхронная логика
│   │   ├── LoggerMiddleware.swift          # Логирование actions
│   │   ├── AuthMiddleware.swift            # Логика авторизации
│   │   ├── MigrationMiddleware.swift       # Миграция с Firebase
│   │   ├── PushNotificationMiddleware.swift # Push уведомления
│   │   ├── AnalyticsMiddleware.swift       # Отправка событий
│   │   └── FeedbackMiddleware.swift        # Haptic feedback
│   ├── Services/                           # Сервисы приложения
│   │   ├── AnalyticsService.swift          # AppMetrica интеграция
│   │   ├── KeychainService.swift           # Безопасное хранение
│   │   ├── APIService.swift                # HTTP клиент
│   │   ├── PushPermissionService.swift     # Push разрешения
│   │   └── TapticFeedbackService.swift     # Haptic Engine
│   ├── Models/                             # Модели данных
│   │   ├── AuthState.swift                 # Состояния авторизации
│   │   ├── EmailAuthState.swift            # Email авторизация
│   │   ├── PhoneAuthState.swift            # Телефонная авторизация
│   │   ├── AuthenticationMethod.swift      # Методы авторизации
│   │   └── UserDetails.swift               # Данные пользователя
│   ├── Utils/                              # Утилиты
│   │   └── Logger.swift                    # Система логирования
│   └── DI/                                 # Dependency Injection
│       ├── ServiceLocator.swift            # DI контейнер
│       └── Injected.swift                  # Property wrapper
├── Features/                               # UI экраны
│   ├── Auth/                               # Авторизация
│   │   └── Views/                          
│   │       ├── WelcomeView.swift           # Экран приветствия
│   │       ├── LoginView.swift             # Роутинг авторизации
│   │       ├── EmailAuth/
│   │       │   ├── EmailEntryView.swift    # Ввод email
│   │       │   ├── EmailCheckingView.swift # Проверка email
│   │       │   ├── PasswordEntryView.swift # Ввод пароля
│   │       │   ├── PasswordVerifyingView.swift # Проверка пароля
│   │       │   ├── PasswordRecoveryView.swift # Восстановление пароля
│   │       │   └── RegistrationView.swift  # Регистрация
│   │       └── PhoneAuth/
│   │           └── PhoneEntryView.swift    # Ввод телефона
│   └── Home/                               # Главный функционал
│       └── Views/
│           └── HomeView.swift              # Домашний экран
├── Common/                                 # Общие компоненты
│   └── Views/
│       └── RootView.swift                  # Корневой роутинг
├── App/                                    # Конфигурация приложения
│   ├── RedCalendar_FemaleApp.swift         # Main app entry point
│   ├── AppDelegate.swift                   # Push notifications
│   └── Configurator.swift                  # Настройка DI сервисов
├── RedCalendar-Female.entitlements         # Entitlements (push notifications)
└── Info.plist                             # App configuration
```

## 🚀 Запуск и развертывание

### Требования
- **Xcode 15.0+**
- **iOS 15.4+**
- **Swift 5.9+**
- **Apple Developer Account** (для push уведомлений)

### Настройка
1. Клонировать репозиторий
2. Открыть `RedCalendar-Female.xcodeproj`
3. Настроить Bundle Identifier и команду разработчика
4. Настроить push notifications в Apple Developer Portal
5. Зарегистрировать TapticFeedbackService в DI контейнере
6. Запустить на устройстве или симуляторе

### Конфигурация
```swift
// Configurator.swift - настройка сервисов
Configurator.shared.setup()

// TapticFeedbackService в ServiceLocator
register(TapticFeedbackServiceProtocol.self) {
    TapticFeedbackService()
}

// AppMetrica
private let apiKey = "***REMOVED***"

// API Endpoints
private let apiBaseURL = "https://api.calendar.red"
```

## 🧪 Тестирование

### Preview Support
Все View поддерживают Xcode Previews с mock данными:
```swift
#Preview {
    EmailEntryView()
        .environmentObject(mockStore)
}

#Preview("Login Sheet") {
    WelcomeView()
        .environmentObject(mockStoreWithAuth)
}
```

### Отладка Redux
```
🎯 Action: setAuthState(.notAuthenticated)
🎯 Action: setAuthState(.authenticating(.email(.entry())))
🎯 Action: setAuthState(.authenticated("device123", userDetails))
```

### Миграция
Тестовая кнопка для проверки миграции с Firebase UID:
```swift
store.send(.setAuthState(.migrating(
    userId: "nSJXOCPF3ocA4Znn1sL7KvI1dh13"
)))
```

### Haptic Feedback Тестирование
```swift
// Тестирование обратной связи
store.send(.setAuthState(.authenticated(deviceId: "test", userDetails: nil))) // Success
store.send(.logout) // Prepare
```

## 🔄 Интеграция с Backend

### API Endpoints
- **POST** `/auth/migrate` - миграция с Firebase
- **GET** `/auth/verify` - проверка device_id
- **PUT** `/auth/apns-token` - обновление APNS токена
- **DELETE** `/auth/logout` - выход из системы

### Authentication
Все запросы используют Bearer authentication:
```
Authorization: Bearer {device_id}
```

### Error Handling
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

## 📈 Планы развития

### Версия 3.1
- ✅ Базовая Redux архитектура
- ✅ Система авторизации (entry экраны)
- ✅ Push notifications
- ✅ Миграция с Firebase
- ✅ Адаптивный UI дизайн
- ✅ Haptic Feedback система

### Версия 3.2
- 🔄 Полные потоки авторизации (пароли, регистрация)
- 🔄 API интеграция для новых методов авторизации
- 🔄 Основные экраны календаря и трекинга
- 🔄 CRUD операции для пользовательских данных
- 🔄 Расширение Haptic Feedback для UI взаимодействий

### Версия 3.3
- 📋 Offline поддержка с синхронизацией
- 📋 Продвинутая аналитика и мониторинг
- 📋 Unit и UI тестирование
- 📋 Локализация на дополнительные языки

## 🤝 Команда

**Разработчик:** Артём Болотов  
**Архитектура:** Redux + SwiftUI  
**Дизайн:** Material Design принципы  
**Backend:** Node.js + PostgreSQL

---

*Версия 3.1 - Январь 2025*  
*Последнее обновление документации: 16.06.2025*
