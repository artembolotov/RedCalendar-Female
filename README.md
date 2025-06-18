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

## 📱 Функциональность

### ✅ Реализовано

**Система авторизации:**
- Email авторизация с валидацией и автозаполнением
- Телефонная авторизация для пользователей версии 2.0
- Детальные состояния для каждого шага процесса
- Миграция с Firebase UID → device_id
- Обработка ошибок на каждом этапе с понятными сообщениями

**Пользовательский интерфейс:**
- Экран приветствия с онбордингом (4 слайда)
- Адаптивная верстка (max width 320pt для форм)
- Автофокус на полях ввода с плавными переходами
- Email suggestions и умное автозаполнение
- Поддержка markdown ссылок в тексте
- Единообразный дизайн-язык на всех экранах

**Push уведомления:**
- Автоматическая регистрация APNS токенов
- Синхронизация токенов с сервером
- Retry механизм при сбоях сети
- Автоматическая очистка badge при активации приложения

**Haptic Feedback (НОВОЕ):**
- **TapticFeedbackService** - сервис для тактильной обратной связи
- Поддержка событий: success, error, warning
- Интеграция через **FeedbackMiddleware** в Redux архитектуру
- Подготовка генераторов для оптимальной производительности

**Техническая часть:**
- Keychain для безопасного хранения sensitive данных
- AppMetrica аналитика с уникальным API ключом
- Система логирования действий и ошибок
- Graceful обработка сетевых ошибок и offline режима

### 🔄 В разработке

**Email/Phone авторизация:**
- Проверка существования email в базе данных
- Экраны ввода пароля и полной регистрации
- Система восстановления пароля через email
- Верификация телефонного номера через СМС

**Основной функционал:**
- CRUD операции для менструальных циклов
- Трекинг симптомов и настроения
- Календарь с предсказаниями овуляции
- Система комментариев и пользовательских тегов

**API интеграция:**
- Синхронизация данных с сервером
- Offline поддержка с локальным кэшированием
- Conflict resolution при расхождении данных

## 🎨 UI/UX Дизайн

### Дизайн-система
- **Максимальная ширина форм:** 320pt для оптимальной читаемости
- **Отступы:** стандартные 16pt по краям экрана
- **Цветовая схема:** красно-розовые градиенты в стиле приложения
- **Типографика:** системный шрифт SF Pro с семантическими размерами

### Адаптивность
- **iPhone:** полноэкранный режим с учётом safe areas
- **iPad:** центрированный контент с ограничением ширины
- **Альбомная ориентация:** сохранение пропорций и читаемости
- **Accessibility:** полная поддержка screen readers и VoiceOver

### Анимации и взаимодействие
- **Page transitions:** плавные переходы между слайдами
- **Loading states:** индикаторы прогресса с понятным feedback
- **Focus management:** автоматическая навигация по полям ввода
- **Error feedback:** визуальные индикаторы ошибок с анимацией
- **Haptic feedback:** тактильная обратная связь для ключевых событий

## 🔐 Безопасность и приватность

### Данные пользователя
- **Keychain Storage** - device_id и sensitive данные
- **No localStorage** - всё в памяти приложения или Keychain
- **HTTPS only** - все соединения защищены TLS
- **Bearer tokens** - device_id в заголовках Authorization

### Приватность
- **Local-first** - данные хранятся локально и синхронизируются
- **No tracking** - только техническая аналитика AppMetrica
- **Encrypted transport** - все API запросы зашифрованы
- **User control** - полный контроль пользователя над своими данными

## 📋 Модели данных

### AuthState - Состояния авторизации
```swift
enum AuthState {
    case notAuthenticated
    case authenticated(deviceId: String, userDetails: UserDetails?)
    case migrating(userId: String, error: Error? = nil)
    case authenticating(AuthenticationMethod)
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
│   │   ├── Middleware/                     # Middleware компоненты
│   │   │   ├── LoggerMiddleware.swift      # Логирование actions
│   │   │   ├── AuthMiddleware.swift        # Логика авторизации
│   │   │   ├── MigrationMiddleware.swift   # Миграция с Firebase
│   │   │   ├── PushNotificationMiddleware.swift # Push уведомления
│   │   │   ├── AnalyticsMiddleware.swift   # Отправка событий
│   │   │   └── FeedbackMiddleware.swift    # 🆕 Haptic feedback
│   │   └── Reducers/
│   │       └── AppReducer.swift            # Reducer функции
│   ├── Services/                           # Сервисы приложения
│   │   ├── AnalyticsService.swift          # AppMetrica интеграция
│   │   ├── KeychainService.swift           # Безопасное хранение
│   │   ├── APIService.swift                # HTTP клиент
│   │   ├── PushPermissionService.swift     # Push разрешения
│   │   └── TapticFeedbackService.swift     # 🆕 Haptic Engine
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
│   │       ├── EmailAuth/                  # Email поток
│   │       │   ├── EmailEntryView.swift    # Ввод email
│   │       │   ├── EmailCheckingView.swift # Проверка email
│   │       │   ├── PasswordEntryView.swift # Ввод пароля
│   │       │   ├── PasswordVerifyingView.swift # Проверка пароля
│   │       │   ├── PasswordRecoveryView.swift # Восстановление пароля
│   │       │   └── RegistrationView.swift  # Регистрация
│   │       └── PhoneAuth/                  # Телефонный поток
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
│   └── Configurator.swift                  # 🆕 Настройка DI сервисов
├── RedCalendar-Female.entitlements         # Entitlements (push notifications)
└── Info.plist                             # App configuration
```

## 🚀 Запуск и развертывание

### Требования
- **Xcode 15.0+**
- **iOS 15.4+** 
- **Swift 5.9+**
- **Apple Developer Account** (для push уведомлений)

### Настройка проекта
1. Клонировать репозиторий с GitHub
2. Открыть `RedCalendar-Female.xcodeproj` в Xcode
3. Настроить Bundle Identifier и команду разработчика
4. Настроить push notifications в Apple Developer Portal
5. Убедиться что TapticFeedbackService зарегистрирован в DI контейнере
6. Запустить на физическом устройстве или симуляторе

### Конфигурация сервисов
```swift
// Configurator.swift - настройка всех сервисов
Configurator.shared.setup()

// TapticFeedbackService в ServiceLocator (новое)
register(TapticFeedbackServiceProtocol.self) {
    TapticFeedbackService()
}

// AppMetrica API ключ
private let apiKey = "***REMOVED***"

// Производственные API endpoints
private let apiBaseURL = "https://api.calendar.red"
```

## 🧪 Тестирование и отладка

### Xcode Previews Support
Все View компоненты поддерживают Xcode Previews с mock данными:
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

### Redux отладка
Логирование всех action'ов в консоль:
```
🎯 Action: setAuthState(.notAuthenticated)
🎯 Action: setAuthState(.authenticating(.email(.entry())))
🎯 Action: setAuthState(.authenticated("device123", userDetails))
```

### Тестирование миграции
Тестовая кнопка для проверки миграции с Firebase UID:
```swift
store.send(.setAuthState(.migrating(
    userId: "nSJXOCPF3ocA4Znn1sL7KvI1dh13"
)))
```

### Haptic Feedback тестирование (НОВОЕ)
```swift
// Тестирование тактильной обратной связи
store.send(.setAuthState(.authenticated(deviceId: "test", userDetails: nil))) // Success feedback
store.send(.logout) // Prepare feedback generators
```

## 🔄 Интеграция с Backend API

### API Endpoints
- **POST** `/auth/migrate` - миграция с Firebase на новую систему
- **GET** `/auth/verify` - проверка действительности device_id
- **PUT** `/auth/apns-token` - обновление APNS токена устройства
- **DELETE** `/auth/logout` - выход из системы

### Authentication
Все API запросы используют Bearer authentication:
```
Authorization: Bearer {device_id}
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

## 📈 Roadmap и планы развития

### Версия 3.1 (Текущая) ✅
- ✅ Базовая Redux архитектура
- ✅ Система авторизации (entry экраны)
- ✅ Push notifications через APNs
- ✅ Миграция с Firebase на собственный сервер
- ✅ Адаптивный UI дизайн
- ✅ **Haptic Feedback система** (TapticFeedbackService + FeedbackMiddleware)

### Версия 3.2 (В разработке) 🔄
- 🔄 Полные потоки авторизации (пароли, регистрация, восстановление)
- 🔄 API интеграция для новых методов авторизации
- 🔄 Основные экраны календаря и трекинга
- 🔄 CRUD операции для пользовательских данных
- 🔄 Расширение Haptic Feedback для всех UI взаимодействий

### Версия 3.3 (Планируется) 📋
- 📋 Offline поддержка с интеллектуальной синхронизацией
- 📋 Продвинутая аналитика и мониторинг производительности
- 📋 Comprehensive unit и UI тестирование
- 📋 Локализация на дополнительные языки

## 🔧 Последние изменения

### **16.06.2025 - Добавлена Haptic Feedback система**

**Новые файлы:**
- `TapticFeedbackService.swift` - сервис для управления тактильной обратной связью
- `FeedbackMiddleware.swift` - middleware для интеграции haptic feedback в Redux

**Изменения:**
- Добавлена регистрация TapticFeedbackService в `Configurator.swift`
- Интеграция haptic events в ключевые моменты пользовательского опыта
- Success feedback при успешной авторизации
- Prepare feedback generators для оптимальной производительности

**Backend обновления:**
- Оптимизация индекса `idx_user_devices_apns_token` для быстрого поиска APNS токенов
- Удаление поля `created_at` из таблицы `user_devices` для упрощения схемы

## 🤝 Команда и технологии

**Разработчик:** Артём Болотов  
**Frontend:** SwiftUI + Redux архитектура  
**Backend:** Node.js + PostgreSQL + APNs  
**Инфраструктура:** NetAngels (Россия)  
**Аналитика:** AppMetrica  
**CI/CD:** GitHub Actions  

## 📄 Документация

- **Backend API:** Документация API endpoints и схемы базы данных
- **Database:** PostgreSQL схема с оптимизациями для производительности
- **Deployment:** Автоматический деплой через GitHub Actions на NetAngels

---

**Версия 3.1** - Январь 2025  
**Последнее обновление:** 18.06.2025  
**Haptic Feedback интеграция:** 16.06.2025
