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
│   └── Home/                               # Главный экран
│       └── Views/
│           └── HomeView.swift              # Главный экран приложения
├── Calendar/                               # Календарная система
│   ├── Core/
│   │   ├── MonthCalculator.swift           # Вычислительное ядро
│   │   ├── CalendarConstants.swift         # Константы конфигурации
│   │   └── CalendarModels.swift            # Модели данных календаря
│   ├── Components/
│   │   ├── InfiniteScrollContainer.swift   # Бесконечная прокрутка
│   │   ├── MonthView.swift                 # Компонент месяца
│   │   └── DayView.swift                   # Компонент дня
│   └── State/
│       ├── ScrollCommand.swift             # Команды управления прокруткой
│       └── FloatingButtonState.swift       # Состояния плавающей кнопки
└── Resources/                              # Ресурсы
    ├── Assets.xcassets                     # Изображения и цвета
    ├── Localizable.strings                 # Локализация
    └── Info.plist                          # Конфигурация приложения
```

### Модели данных в Core

```swift
// Daystamp - типобезопасный тип для работы с датами
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

## 🔧 Последние изменения

### **Август 2025 - Типобезопасная система дат**

**Новые файлы:**
- `Daystamp.swift` - структура для типобезопасной работы с датами

**Ключевые особенности:**
- Замена typealias на полноценную структуру
- Поддержка всех математических операций (+, -, +=, -=)
- Протоколы: Comparable, AdditiveArithmetic, Codable, ExpressibleByIntegerLiteral
- Безопасная конвертация между Date и Daystamp через Calendar
- Отладочный вывод в формате "Daystamp(100 -> 2001-04-10)"
- Референсная дата: 1 января 2001

**Примеры использования:**
```swift
let today: Daystamp = 100              // ExpressibleByIntegerLiteral
let tomorrow = today + 1               // Математические операции
let lastWeek = today - 7
let difference = tomorrow - today      // = 1

if today > lastWeek { ... }            // Сравнения
let range = today...(today + 30)       // Диапазоны

// Конвертация с Date
let dayFromDate = Daystamp(from: Date(), calendar: calendar)
let dateFromDay = today.toDate(calendar: calendar)
```

### **Август 2025 - Продвинутая календарная система**

**Новые файлы:**
- `MonthCalculator.swift` - вычислительное ядро календаря
- `InfiniteScrollContainer.swift` - бесконечная прокрутка
- `CalendarConstants.swift` - константы конфигурации
- `CalendarModels.swift` - модели данных календаря
- `ScrollCommand.swift` - команды управления прокруткой
- `FloatingButtonState.swift` - состояния плавающей кнопки

**Ключевые особенности:**
- Виртуализированный рендеринг с кэшированием
- Поддержка диапазона ±200 лет
- Интеллектуальное управление памятью
- Полная локализация календаря
- Оптимизированный viewport tracking

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
- **Debug-Staging** - Staging environment
- **Release-Staging** - Staging production build
- Настройки API_BASE_URL в build configurations

## 📈 Roadmap

### Версия 3.1 (Текущая) ✅
- ✅ Базовая Redux архитектура
- ✅ Email и Flash Call авторизация
- ✅ Push notifications через APNs
- ✅ Унифицированная модель UserDetails
- ✅ Haptic Feedback система
- ✅ Продвинутая календарная система с виртуализацией
- ✅ Типобезопасная система дат (Daystamp)

### Версия 3.2 (В разработке) 🔄
- 🔄 Интеграция данных циклов в календарь с использованием Daystamp
- 🔄 CRUD операции для пользовательских данных
- 🔄 Система тегов и симптомов
- 🔄 Offline поддержка с синхронизацией

### Версия 3.3 (Планируется) 📋
- 📋 Продвинутая аналитика и прогнозы на основе Daystamp
- 📋 Comprehensive unit и UI тестирование
- 📋 Локализация на дополнительные языки
- 📋 Виджеты для iOS

---

**Разработчик:** Артём Болотов  
**Архитектура:** SwiftUI + Redux + Virtual Calendar + Type-Safe Dates  
**Версия:** 3.1 - Август 2025
