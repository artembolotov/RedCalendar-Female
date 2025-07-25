# RedCalendar iOS 3.0

Современное iOS приложение для отслеживания менструального цикла, полностью переписанное на SwiftUI с Redux архитектурой.

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
│   ├── Home/                               # Основной функционал
│   │   ├── HomeView.swift                  # Главный экран
│   │   └── CalendarView.swift              # Календарь менструального цикла
│   ├── Settings/                           # Настройки
│   │   └── SettingsView.swift              # Экран настроек
│   └── Statistics/                         # Статистика
│       └── StatisticsView.swift            # Экран статистики
└── Resources/                              # Ресурсы
    ├── Assets.xcassets                     # Изображения и цвета
    ├── Localizable.strings                 # Локализация
    └── Info.plist                          # Конфигурация приложения
```

## 📱 Функциональность

### ✅ Реализовано

**Система авторизации:**
- ✅ Email авторизация с валидацией и автозаполнением
- ✅ Flash Call авторизация для пользователей версии 2.0
- ✅ Детальные состояния для каждого шага процесса
- ✅ Миграция с Firebase UID → device_id
- ✅ Обработка ошибок на каждом этапе с понятными сообщениями
- ✅ Единая модель UserDetails для всех методов auth

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

### Flash Call Authentication Flow

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
        requestId: String,
        error: AuthenticationError? = nil
    )
    case verifying(
        prettyPhoneNumber: String,
        e164PhoneNumber: String,
        requestId: String,
        verificationCode: String
    )
}
```

### Email Authentication Flow

#### Email Auth States

```swift
enum EmailAuthState {
    case entry(email: String? = nil, error: Error? = nil)
    case checking(email: String, name: String? = nil)
    case codeEntry(email: String, code: String? = nil, userName: String? = nil, error: AuthenticationError? = nil)
    case verifying(email: String, code: String, name: String? = nil)
    case registration(email: String, code: String?, name: String? = nil)
}
```

## ⚙️ Технологический стек

### Основные зависимости
- **SwiftUI** - декларативный UI фреймворк
- **Combine** - реактивное программирование
- **Redux** - управление состоянием
- **Dependency Injection** - архитектурный паттерн

### Внешние библиотеки (SPM)
- **AppMetrica** (5.11.1) - аналитика и crash reporting
  - AppMetricaCore
  - AppMetricaCrashes
- **PhoneNumberKit** (4.1.1) - валидация и форматирование номеров

## 🔧 Последние изменения

### **Июль 2025 - Flash Call Authentication**

**Новые файлы:**
- `FlashCallCodeEntryView.swift` - UI для Flash Call верификации
- `PhoneAuthState.swift` - состояния телефонной аутентификации
- Обновленный `UserDetails.swift` - унифицированная модель пользователя

**Изменения:**
- Расширен `AuthMiddleware` для обработки phone auth
- Добавлены методы `checkPhone` и `verifyFlashCall` в `APIService`
- Унифицированы все API response models
- Обновлен `LoginView` для поддержки Flash Call flow

### **Июнь 2025 - Haptic Feedback система**

**Новые файлы:**
- `TapticFeedbackService.swift` - сервис для управления тактильной обратной связью
- `FeedbackMiddleware.swift` - middleware для интеграции haptic feedback в Redux

**Изменения:**
- Добавлена регистрация TapticFeedbackService в `Configurator.swift`
- Интеграция haptic events в ключевые моменты пользовательского опыта
- Success feedback при успешной авторизации

## 🚀 Setup & Development

### Требования
- iOS 15.4+
- Xcode 16.4+
- Swift 5.9+

### Установка
1. Клонировать репозиторий
2. Открыть `RedCalendar-Female.xcodeproj` в Xcode
3. Настроить Bundle Identifier и команду разработчика
4. Настроить push notifications в Apple Developer Portal
5. Убедиться что все сервисы зарегистрированы в DI контейнере

### Конфигурация окружений
- **Debug** - Development API endpoint
- **Release** - Production API endpoint
- Настройки API_BASE_URL в build configurations

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

**Разработчик:** Артём Болотов  
**Архитектура:** SwiftUI + Redux  
**Версия:** 3.1 - Июль 2025
