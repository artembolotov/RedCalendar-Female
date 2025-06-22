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
- Синхронизация с сервером через middleware
- Background refresh для обновления токенов

**Haptic Feedback система:**
- TapticFeedbackService для управления тактильной обратной связью
- FeedbackMiddleware для интеграции в Redux
- Success/Error/Prepare feedback для ключевых событий

### 🔄 В разработке
- Полные потоки авторизации (password entry, verification, recovery)
- Основные экраны календаря и трекинга
- CRUD операции для пользовательских данных
- Расширение Haptic Feedback для всех UI взаимодействий

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
│   │   │   └── FeedbackMiddleware.swift    # 🆕 Haptic feedback
│   │   └── Reducers/
│   │       └── AppReducer.swift            # Reducer функции
│   ├── Services/                           # Сервисы приложения
│   │   ├── AnalyticsService.swift          # AppMetrica интеграция
│   │   ├── KeychainService.swift           # Безопасное хранение
│   │   ├── APIService.swift                # HTTP клиент
│   │   └── TapticFeedbackService.swift     # 🆕 Haptic Engine
│   └── Utils/                              # Утилиты
│       └── Logger.swift                    # Система логирования
├── Features/                               # UI экраны
│   ├── Auth/                               # Авторизация
│   │   └── Views/                          
│   │       ├── WelcomeView.swift           # Экран приветствия
│   │       ├── LoginView.swift             # Роутинг авторизации
│   │       ├── EmailAuth/                  # Email поток
│   │       │   ├── EmailEntryView.swift    # Ввод email
│   │       │   └── CodeEntryView.swift     # Ввод кода подтверждения
│   │       └── PhoneAuth/                  # Телефонный поток
│   │           └── PhoneEntryView.swift    # Ввод телефона
│   └── Home/                               # Главный функционал
│       └── Views/
│           └── HomeView.swift              # Домашний экран
├── Common/                                 # Общие компоненты
│   └── Views/
│       ├── RootView.swift                  # Корневой роутинг
│       └── WaitingView.swift               # Компонент загрузки
├── Assets.xcassets/                        # Ресурсы приложения
│   ├── AccentColor.colorset/               # Акцентный цвет
│   ├── AppIcon.appiconset/                 # Иконки приложения
│   └── Contents.json                       # Манифест ресурсов
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

### Зависимости
Проект использует Swift Package Manager для управления зависимостями:
- **AppMetrica** - аналитика и мониторинг
  - AppMetricaCore
  - AppMetricaCrashes

## 🔄 API интеграция

Приложение взаимодействует с собственным сервером для:
- Миграции пользователей с Firebase
- Синхронизации APNS токенов
- Проверки состояния авторизации

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
- Интеграция с собственным API сервером
- Миграция пользователей с Firebase системы

## 🤝 Команда и технологии

**Разработчик:** Артём Болотов  
**Frontend:** SwiftUI + Redux архитектура  
**Аналитика:** AppMetrica  
**Платформа:** iOS 15.4+, Xcode 16.4  

## 📄 Документация

- **Архитектура:** Redux State Management с SwiftUI
- **Dependency Injection:** ServiceLocator паттерн
- **API интеграция:** RESTful клиент с async/await

---

**Версия 3.1** - Январь 2025  
**Последнее обновление:** 22.06.2025  
**Haptic Feedback интеграция:** 16.06.2025
