# RedCalendar iOS 3.0

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
│   │   ├── UserDetails.swift               # Данные пользователя
│   │   └── Daystamp.swift                  # Типобезопасный тип даты
│   ├── Redux/                              # Redux архитектура
│   │   ├── Actions/
│   │   │   └── AppAction.swift             # Действия приложения
│   │   ├── States/
│   │   │   └── AppState.swift              # Глобальное состояние
│   │   ├── Store.swift                     # Store реализация
│   │   ├── AppStore.swift                  # Type alias для Store
│   │   ├── AppMiddleware.swift             # Основной middleware
│   │   ├── AuthMiddleware.swift            # Auth обработка
│   │   ├── PushMiddleware.swift            # Push notifications
│   │   └── FeedbackMiddleware.swift        # Haptic feedback
│   └── Services/                           # Бизнес-логика
│       ├── APIService.swift                # REST API клиент
│       ├── AuthStorage.swift               # Локальное хранение auth
│       └── TapticFeedbackService.swift     # Тактильная обратная связь
├── Features/                               # Функциональные модули
│   ├── Auth/                               # Авторизация
│   │   ├── Views/
│   │   │   ├── WelcomeView.swift            # Экран приветствия (4 слайда)
│   │   │   ├── LoginView.swift              # Выбор метода авторизации
│   │   │   ├── EmailAuthView.swift          # Email авторизация
│   │   │   ├── EmailCodeEntryView.swift     # Ввод кода из email
│   │   │   ├── PhoneAuthView.swift          # Flash Call авторизация
│   │   │   └── FlashCallCodeEntryView.swift # Ввод кода Flash Call
│   │   └── Components/
│   │       ├── SlideView.swift             # Компонент слайда онбординга
│   │       ├── AuthTextField.swift         # Стилизованное поле ввода
│   │       └── ContinueButton.swift        # Кнопка продолжения
│   └── Home/                               # Главный экран с интегрированным календарем
│       ├── Views/
│       │   └── HomeView.swift              # Главный экран приложения
│       └── Calendar/                       # Календарная система (интегрирована в Home)
│           ├── Core/
│           │   ├── MonthCalculator.swift           # Вычислительное ядро
│           │   ├── CalendarConstants.swift         # Константы конфигурации
│           │   └── CalendarModels.swift            # Модели данных календаря
│           ├── Components/
│           │   ├── InfiniteScrollContainer.swift   # Бесконечная прокрутка
│           │   ├── MonthView.swift                 # Компонент месяца
│           │   └── DayView.swift                   # Компонент дня
│           ├── Models/
│           │   └── ScrollCommand.swift             # Команды управления прокруткой
│           └── State/
│               └── FloatingButtonState.swift       # Состояния плавающей кнопки
└── Resources/                              # Ресурсы
    ├── Assets.xcassets                     # Изображения и цвета
    ├── Localizable.strings                 # Локализация
    └── Info.plist                          # Конфигурация приложения
```

### Модели данных в Core

```swift
// Daystamp - типобезопасный тип для работы с датами
struct Daystamp {
    let rawValue: Int
    // Математические операции, конвертация с Date, Codable поддержка
}

enum EmailAuthState {
    case idle(email: String? = nil, name: String? = nil, error: Error? = nil)
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

### Кастомные типы данных
- **Daystamp** - типобезопасная альтернатива Int для работы с календарными датами
  - Математические операции (+, -, сравнения)
  - Конвертация с Date через Calendar
  - Codable для сериализации
  - CustomStringConvertible для отладки

## 🚀 Setup & Development

### Требования
- iOS 15.4+
- Xcode 16.4+
- Swift 5.9+

### Конфигурация окружений
- **Debug** - Development API endpoint
- **Release** - Production API endpoint
- **Debug-Staging** - Staging environment
- **Release-Staging** - Staging production build
- Настройки API_BASE_URL в build configurations

## 📈 Roadmap

### Версия 3.2 (Текущая) ✅
- ✅ Базовая Redux архитектура
- ✅ Email и Flash Call авторизация
- ✅ Push notifications через APNs
- ✅ Унифицированная модель UserDetails
- ✅ Haptic Feedback система
- ✅ Продвинутая календарная система с виртуализацией
- ✅ Типобезопасная система дат (Daystamp)
- ✅ Визуализация выбранного дня в календаре (**NEW**)

### Версия 3.3 (В разработке) 🔄
- 🔄 CRUD операции для пользовательских данных
- 🔄 Система тегов и симптомов
- 🔄 Offline поддержка с синхронизацией
- 🔄 Подключение к новому API (api.calendar.red)
- 🔄 Взаимодействие с выбранным днем (тапы, данные цикла)

### Версия 3.4 (Планируется) 📋
- 📋 Продвинутая аналитика и прогнозы на основе Daystamp
- 📋 Comprehensive unit и UI тестирование
- 📋 Локализация на дополнительные языки
- 📋 Виджеты для iOS

## 📄 Лицензия

Исходный код открыт для ознакомления. Использование, копирование или распространение без письменного разрешения автора запрещено. Подробнее — в файле [LICENSE](LICENSE).

---

**Разработчик:** Артём Болотов  
**Архитектура:** SwiftUI + Redux + Integrated Calendar + Type-Safe Dates
