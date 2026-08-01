# RedCalendar iOS 3.3

Современное iOS приложение для отслеживания менструального цикла, полностью переписанное на SwiftUI с Redux архитектурой и продвинутой календарной системой.

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
├── App/
│   ├── RedCalendar_FemaleApp.swift         # Main app entry point
│   ├── AppDelegate.swift                   # Push notifications
│   └── Configurator.swift                  # Настройка DI сервисов
├── Core/
│   ├── Constants.swift                     # API URL и прочие константы
│   ├── DI/
│   │   ├── ServiceLocator.swift            # DI контейнер
│   │   └── Injected.swift                  # Property wrapper
│   ├── Models/
│   │   ├── AuthenticationMethod.swift
│   │   ├── AuthenticationError.swift
│   │   ├── APNSToken.swift
│   │   ├── UserDetails.swift
│   │   ├── Daystamp.swift                  # Типобезопасный тип даты
│   │   ├── CycleRecord.swift               # GRDB-запись цикла
│   │   ├── CommentRecord.swift             # GRDB-запись комментария
│   │   ├── UserTagRecord.swift             # GRDB-запись пользовательского тега
│   │   └── DayTagsRecord.swift             # GRDB-запись тегов дня
│   ├── Redux/
│   │   ├── Actions/
│   │   │   └── AppAction.swift
│   │   ├── Middleware/
│   │   │   ├── AuthMiddleware.swift        # Авторизация, logout, checkAuthState
│   │   │   ├── MigrationMiddleware.swift   # Миграция с Firebase
│   │   │   ├── PushNotificationsMiddleware.swift
│   │   │   ├── AnalyticsMiddleware.swift
│   │   │   ├── FeedbackMiddleware.swift    # Haptic feedback
│   │   │   └── LoggerMiddleware.swift
│   │   ├── Reducers/
│   │   │   └── AppReducer.swift
│   │   ├── States/
│   │   │   ├── AppState.swift              # Глобальное состояние + convenience properties
│   │   │   ├── AuthState.swift
│   │   │   ├── CalendarState.swift
│   │   │   ├── EmailAuthState.swift
│   │   │   ├── PhoneAuthState.swift
│   │   │   └── NotificationState.swift
│   │   ├── AppMiddleware.swift             # combineAppMiddlewares()
│   │   ├── AppStore.swift                  # typealias AppStore
│   │   └── Store.swift                     # Generic Store<State, Action>
│   ├── Services/
│   │   ├── APIService.swift                # REST API клиент
│   │   ├── DatabaseService.swift           # GRDB локальная БД
│   │   ├── DatabaseServiceProtocol.swift   # Протокол БД-сервиса
│   │   ├── KeychainService.swift           # Keychain (deviceId)
│   │   ├── AnalyticsService.swift          # AppMetrica обёртка
│   │   ├── PushPermissionService.swift
│   │   └── TapticFeedbackService.swift
│   └── Utils/
│       └── Logger.swift                    # AppLogger
├── Common/
│   ├── Components/
│   │   ├── PrimaryButton.swift
│   │   ├── CloseButton.swift
│   │   └── PhoneNumberKitField.swift
│   ├── Extensions/
│   │   ├── Bundle+AppInfo.swift
│   │   ├── String+Validation.swift
│   │   ├── Shape+AdaptiveBackground.swift
│   │   └── View+AdaptiveShadow.swift
│   ├── Modifiers/
│   │   └── FormFieldStyle.swift
│   └── Views/
│       ├── RootView.swift
│       └── WaitingView.swift
├── Features/
│   ├── Auth/
│   │   └── Views/
│   │       ├── WelcomeView.swift
│   │       ├── LoginView.swift
│   │       ├── EmailAuth/
│   │       │   ├── EmailEntryView.swift
│   │       │   └── CodeEntryView.swift
│   │       └── PhoneAuth/
│   │           ├── PhoneEntryView.swift
│   │           └── FlashCallCodeEntryView.swift
│   ├── Home/
│   │   ├── Calendar/
│   │   │   ├── CalendarView.swift
│   │   │   ├── Components/
│   │   │   │   ├── CalendarHeaderView.swift
│   │   │   │   └── InfiniteScrollContainer.swift
│   │   │   └── Models/
│   │   │       ├── CalendarModels.swift
│   │   │       ├── CalendarConstants.swift
│   │   │       ├── MonthCalculator.swift
│   │   │       ├── ScrollCommand.swift
│   │   │       └── ViewportCalculator.swift
│   │   ├── Components/
│   │   │   ├── FloatingAddButton.swift
│   │   │   └── HomeMenuView.swift
│   │   ├── HomeView.swift
│   │   ├── DayDetailsView.swift
│   │   └── FloatingButtonState.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Statistics/
│       └── StatisticsView.swift
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

## ⚙️ Технологический стек

### Основные зависимости
- **SwiftUI** - декларативный UI фреймворк
- **Redux** - управление состоянием (hand-rolled)
- **Keychain** - хранение deviceId

### Внешние библиотеки (SPM)
- **AppMetrica** (5.11.1) - аналитика и crash reporting
- **PhoneNumberKit** (4.1.1) - валидация и форматирование номеров
- **GRDB** (7.x) - локальная SQLite база данных

### Кастомные типы данных
- **Daystamp** - типобезопасная альтернатива Int для работы с календарными датами. Reference date — 1 января 2001 года. Поддерживает арифметику, сравнения, конвертацию с `Date` через `Calendar`, `Codable`.

## 🔐 Аутентификация и deviceId

`deviceId` — идентификатор аутентификационной сессии, выдаётся сервером при логине.

- **Хранится:** в `AuthState.authenticated(deviceId:)` и в Keychain (`"redcalendar_device_id"`)
- **Устанавливается:** при email/phone-авторизации или миграции с Firebase
- **Используется:** как Bearer-токен в заголовке `Authorization` всех API-запросов
- **Удаляется:** при logout (из состояния и из Keychain)
- **Читается в views:** через `store.state.deviceId` (convenience property на `AppState`)

## 🚀 Setup & Development

### Требования
- iOS 15.4+
- Xcode 16.4+
- Swift 5.9+

### Конфигурация окружений

| Scheme | Config | API |
|---|---|---|
| RedCalendar-Female (Debug) | Debug | Dev |
| RedCalendar-Female (Release) | Release | Production |
| Staging Debug | Debug-Staging | Staging |
| Staging Release | Release-Staging | Staging |

`API_BASE_URL` задаётся в build configurations и читается через `Constants.URLs.api`.

## 📈 Roadmap

### Версия 3.2 ✅
- ✅ Redux архитектура
- ✅ Email и Flash Call авторизация
- ✅ Миграция с Firebase
- ✅ Push notifications (APNs)
- ✅ Haptic Feedback
- ✅ Бесконечный календарь с виртуализацией
- ✅ Типобезопасная система дат (Daystamp)

### Версия 3.3 (В разработке) 🔄
- 🔄 CRUD операции для пользовательских данных цикла
- 🔄 Система тегов и симптомов
- 🔄 Offline поддержка с синхронизацией
- 🔄 Новый API endpoint: `api.calendar.red`
- 🔄 Взаимодействие с выбранным днём (ввод данных из календаря)

### Версия 3.4 (Планируется) 📋
- 📋 Прогнозы цикла на основе Daystamp
- 📋 Unit и UI тестирование
- 📋 Локализация на дополнительные языки
- 📋 Виджеты для iOS

## 📄 Лицензия

Исходный код открыт для ознакомления. Использование, копирование или распространение без письменного разрешения автора запрещено. Подробнее — в файле [LICENSE](LICENSE).

---

**Разработчик:** Артём Болотов  
**Архитектура:** SwiftUI + Redux + GRDB + Keychain
