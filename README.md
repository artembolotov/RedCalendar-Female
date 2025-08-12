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
│   │   └── UserDetails.swift               # Данные пользователя
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
│       ├── HomeView.swift                  # Контейнер главного экрана
│       ├── HomeMenuView.swift              # Меню в navigation bar
│       ├── FloatingButtonState.swift       # Состояния плавающей кнопки
│       └── Calendar/                       # 📅 КАЛЕНДАРНАЯ СИСТЕМА
│           ├── CalendarView.swift          # Основной календарный интерфейс
│           ├── Components/
│           │   ├── InfiniteScrollContainer.swift # Бесконечная прокрутка
│           │   ├── CalendarHeaderView.swift      # Заголовки дней недели
│           │   ├── MonthView.swift               # Отображение месяца
│           │   ├── DayView.swift                 # Отображение дня
│           │   └── FloatingAddButton.swift       # Плавающая кнопка
│           └── Models/
│               ├── MonthCalculator.swift         # Расчеты календаря
│               ├── CalendarConstants.swift       # Константы календаря
│               ├── CalendarModels.swift          # Модели данных
│               └── ScrollCommand.swift           # Команды прокрутки
└── Resources/                              # Ресурсы
    ├── Assets.xcassets                     # Изображения и цвета
    ├── Localizable.strings                 # Локализация
    └── Info.plist                          # Конфигурация приложения
```

## 📅 Календарная система - Подробная архитектура

### Ключевые компоненты

#### 🎯 **CalendarView** - Главный контроллер
```swift
struct CalendarView: View {
    @Binding var bottomCenterOffset: CGFloat
    @Binding var floatingButtonState: FloatingButtonState
    @Binding var scrollCommand: ScrollCommand
    
    @State private var calculator: MonthCalculator?
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var currentDate = Date()
    @State private var localizedWeekdays: [String] = []
}
```

**Ответственность:**
- Управление состоянием прокрутки и viewport
- Координация между UI компонентами
- Обновление плавающей кнопки в зависимости от позиции
- Локализация календаря

#### ⚡ **MonthCalculator** - Вычислительное ядро
```swift
final class MonthCalculator: ObservableObject {
    let currentDate: Date
    let currentYear: Int
    let screenHeight: CGFloat
    
    private var weekCountCache: [Int: Int] = [:]
    private var monthHeightCache: [Int: CGFloat] = [:]
    private var monthDaysCache: [Int: [Date?]] = [:]
    private var cumulativePositionCache: [Int: CGFloat] = [0: 0]
}
```

**Возможности:**
- **Кэширование** - интеллектуальное кэширование вычислений
- **Виртуализация** - расчет только видимых месяцев
- **Локализация** - поддержка разных первых дней недели
- **Оптимизация** - автоматическая очистка кэша при превышении лимитов
- **Диапазон** - поддержка ±2400 месяцев (200 лет в каждую сторону)

#### 🔄 **InfiniteScrollContainer** - Бесконечная прокрутка
```swift
struct InfiniteScrollContainer: UIViewRepresentable {
    private let contentHeight: CGFloat = 8000000  // 8 миллионов точек
    private let centerY: CGFloat = 4000000        // Центр контента
}
```

**Технические решения:**
- **UIViewRepresentable** - мост между SwiftUI и UIKit
- **Огромный contentSize** - 8 млн точек для плавной прокрутки
- **Автоматический recentering** - предотвращение overflow
- **Лимиты прокрутки** - ограничения через calculator.getScrollLimits()
- **Drag state tracking** - отслеживание состояния перетаскивания

#### 📐 **CalendarConstants** - Конфигурация
```swift
enum CalendarConstants {
    static let weekdaysHeaderHeight: CGFloat = 31
    static let monthHeaderHeight: CGFloat = 60
    static let viewportUpdateThreshold: CGFloat = 30
    static let minMonthOffset: Int = -2400  // 200 лет назад
    static let maxMonthOffset: Int = 2400   // 200 лет вперед
}
```

#### 🎛 **FloatingButtonState** - Умная навигация
```swift
enum FloatingButtonState: Equatable {
    case plus        // Сегодня видно - показать плюс
    case arrowUp     // Сегодня ушло вниз - показать стрелку вверх
    case arrowDown   // Сегодня ушло вверх - показать стрелку вниз
}
```

#### 📜 **ScrollCommand** - Программное управление
```swift
enum ScrollCommand: Equatable {
    case none
    case animateToCenter  // Анимированная прокрутка к сегодня
}
```

### Алгоритмы и оптимизации

#### 1. **Viewport Tracking System**
```swift
private func updateViewportTracking() {
    let baseThreshold: CGFloat = CalendarConstants.viewportUpdateThreshold
    let adaptiveThreshold = isDragging ? 
        baseThreshold * 0.5 : baseThreshold
    
    let shouldUpdate = abs(scrollOffset - lastViewportUpdateScroll) > adaptiveThreshold
}
```

#### 2. **Dynamic Height Calculation**
```swift
var weekHeight: CGFloat {
    return floor(max(50, (screenHeight - CalendarConstants.weekdaysHeaderHeight) / 15))
}
```

#### 3. **Cache Management**
```swift
private func cleanupCacheIfNeeded() {
    if weekCountCache.count > 200 {
        let sortedKeys = weekCountCache.keys.sorted { abs($0) > abs($1) }
        let keysToRemove = Array(sortedKeys.prefix(50))
        // Удаляем самые далекие от центра месяцы
    }
}
```

#### 4. **Scroll Limits Protection**
```swift
func getScrollLimits() -> (min: CGFloat, max: CGFloat) {
    let firstMonthY = getYPosition(for: minMonthOffset)
    let lastMonthY = getYPosition(for: maxMonthOffset)
    let lastMonthHeight = getMonthHeight(for: maxMonthOffset)
    
    let maxScrollUp = -firstMonthY
    let availableHeight = screenHeight - 31
    let maxScrollDown = availableHeight - (lastMonthY + lastMonthHeight)
    
    return (min: maxScrollDown, max: maxScrollUp)
}
```

### Производительность календаря

#### ✅ **Оптимизации**
- **Lazy rendering** - рендеринг только видимого viewport
- **Intelligent caching** - кэширование вычислений позиций
- **Adaptive thresholds** - разные пороги обновления для drag/scroll
- **Memory management** - автоматическая очистка кэша
- **Localization caching** - кэширование локализованных строк

#### 📊 **Metrics**
- **Поддерживаемый диапазон**: ±200 лет (4800 месяцев)
- **Размер content**: 8 млн точек для плавной прокрутки
- **Cache size**: до 200 месяцев с автоочисткой
- **Update threshold**: 30pt с адаптацией под drag state
- **Memory footprint**: минимальный за счет виртуализации

## 📱 Функциональность

### ✅ Реализовано

**Система авторизации:**
- ✅ Email авторизация с валидацией и автозаполнением
- ✅ Flash Call авторизация для пользователей версии 2.0
- ✅ Детальные состояния для каждого шага процесса
- ✅ Миграция с Firebase UID → device_id
- ✅ Обработка ошибок на каждом этапе с понятными сообщениями
- ✅ Единая модель UserDetails для всех методов auth

**Календарная система:**
- ✅ Бесконечная прокрутка с виртуализацией
- ✅ Интеллектуальное кэширование вычислений
- ✅ Полная локализация (дни недели, месяцы)
- ✅ Адаптивная высота дней под разные экраны
- ✅ Оптимизированный viewport tracking
- ✅ Плавающая кнопка с умной навигацией
- ✅ Поддержка диапазона ±200 лет
- ✅ Автоматическое управление памятью

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
- 🔄 CRUD операции для циклов и симптомов
- 🔄 Интеграция данных в календарные дни
- 🔄 Расширение Haptic Feedback для календарных взаимодействий
- 🔄 Offline поддержка с синхронизацией

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

### Версия 3.2 (В разработке) 🔄
- 🔄 Интеграция данных циклов в календарь
- 🔄 CRUD операции для пользовательских данных
- 🔄 Система тегов и симптомов
- 🔄 Offline поддержка с синхронизацией

### Версия 3.3 (Планируется) 📋
- 📋 Продвинутая аналитика и прогнозы
- 📋 Comprehensive unit и UI тестирование
- 📋 Локализация на дополнительные языки
- 📋 Виджеты для iOS

---

**Разработчик:** Артём Болотов  
**Архитектура:** SwiftUI + Redux + Virtual Calendar  
**Версия:** 3.1 - Август 2025
