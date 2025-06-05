# RedCalendar

iOS приложение для отслеживания менструального цикла с облачной синхронизацией.

## 🏗 Архитектура

### Redux/Flux Pattern
- **Store**: Единственный источник истины для состояния приложения
- **Actions**: Все изменения состояния происходят через actions
- **Reducer**: Чистые функции без side effects, только трансформация состояния
- **Middleware**: Вся асинхронная логика и side effects

### 📋 Ключевые принципы

1. **Reducer НИКОГДА не содержит side effects**
   - ❌ NO: API calls, Keychain access, Analytics, Timers
   - ✅ YES: Только изменение состояния

2. **Все side effects только в middleware**
   - API запросы
   - Работа с Keychain
   - Аналитика
   - Навигация

3. **Middleware возвращает массив actions: `[Action]`**
   ```swift
   let authMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
       // Всегда возвращаем массив, даже если пустой
       return []
   }
   ```

4. **Computed properties вместо дублирования состояния**
   ```swift
   var isAuthenticated: Bool {
       deviceId != nil  // Вычисляется, а не хранится
   }
   ```

5. **Все сервисы через протоколы и ServiceLocator**
   ```swift
   @Injected var keychain: KeychainServiceProtocol
   ```

## 📁 Структура проекта

```
RedCalendar-Female/
├── App/
│   ├── RedCalendar_FemaleApp.swift    # Точка входа
│   └── Configurator.swift              # Настройка DI
│
├── Core/
│   ├── Redux/
│   │   ├── Store.swift                 # Redux store
│   │   ├── AppStore.swift              # Type alias
│   │   ├── AppMiddleware.swift         # Композиция middleware
│   │   ├── States/
│   │   │   └── AppState.swift
│   │   ├── Actions/
│   │   │   └── AppAction.swift
│   │   ├── Reducers/
│   │   │   └── AppReducer.swift
│   │   └── Middleware/
│   │       ├── AuthMiddleware.swift
│   │       ├── MigrationMiddleware.swift
│   │       ├── LoggerMiddleware.swift
│   │       └── AnalyticsMiddleware.swift
│   │
│   ├── DI/
│   │   ├── ServiceLocator.swift        # DI контейнер
│   │   └── Injected.swift              # Property wrapper
│   │
│   ├── Services/
│   │   ├── KeychainService.swift       # Безопасное хранение
│   │   ├── APIService.swift            # HTTP клиент для API
│   │   └── AnalyticsService.swift      # AppMetrica
│   │
│   └── Utils/
│       └── Logger.swift                # Централизованное логирование
│
├── Features/
│   ├── Auth/
│   │   └── Views/
│   │       └── LoginView.swift
│   │
│   └── Home/
│       └── Views/
│           └── HomeView.swift
│
└── Common/
    └── Views/
        └── RootView.swift              # Корневой роутер
```

## 🚀 Текущий функционал

### Авторизация и миграция
- ✅ **Автоматическая миграция с Firebase** на собственную систему
- ✅ **Проверка device_id при запуске** через Keychain
- ✅ **Плавный переход**: Firebase UID → device_id
- ✅ **Безопасное хранение** credentials в Keychain
- ✅ **API интеграция** с https://api.calendar.red

### Архитектура
- ✅ **Redux state management** с middleware
- ✅ **Dependency Injection** через ServiceLocator
- ✅ **Централизованное логирование** с AppLogger
- ✅ **AppMetrica аналитика** для отслеживания событий
- ✅ **Async/await поддержка** в middleware

## 🔄 Flow авторизации

### Сценарий 1: Пользователь с device_id (новая система)
```
Запуск → checkAuth → device_id найден → authCheckCompleted → HomeView
```

### Сценарий 2: Миграция с Firebase
```
Запуск → checkAuth → user_uid найден → startMigration → 
API /auth/migrate → migrationCompleted → authCheckCompleted → HomeView
```

### Сценарий 3: Новый пользователь
```
Запуск → checkAuth → ничего не найдено → notAuthenticated → LoginView
```

## 🛠 Tech Stack

- **UI**: SwiftUI (iOS 15.4+)
- **Architecture**: Redux/Flux with async middleware
- **DI**: ServiceLocator + @Injected property wrapper
- **Storage**: Keychain for secure device_id storage
- **Analytics**: AppMetrica (Яндекс.Метрика)
- **Backend**: Собственное API на Node.js + PostgreSQL
- **Hosting**: NetAngels shared hosting

## 🔧 Миграция с Firebase

### Логика миграции
1. **Старое приложение** сохраняло Firebase UID в keychain
2. **Новое приложение** при запуске:
   - Ищет device_id (новая система) → используует если найден
   - Ищет user_uid (Firebase legacy) → запускает миграцию
   - Ничего не найдено → показывает экран входа

### API взаимодействие
```swift
// Миграция пользователя
POST /auth/migrate
{
    "user_id": "nSJXOCPF3ocA4Znn1sL7KvI1dh13",
    "device_model": "iPhone"
}

// Ответ
{
    "success": true,
    "data": {
        "device_id": "B7DDU4pUigTiAhpNDWnQW83tGQ6R",
        "user_id": "nSJXOCPF3ocA4Znn1sL7KvI1dh13"
    }
}
```

### Безопасность
- **device_id** хранится в iOS Keychain (зашифровано)
- **Firebase UID удаляется** после успешной миграции
- **HTTPS API** с Bearer token авторизацией
- **28-символьный device_id** в Firebase-совместимом формате

## 💻 Разработка

### Добавление нового Action

1. Добавить case в `AppAction`:
```swift
enum AppAction {
    case existingAction
    case newAction(parameter: String)  // ← Новый
}
```

2. Обработать в reducer (без side effects!):
```swift
case .newAction(let parameter):
    state.someProperty = parameter
```

3. Добавить middleware для side effects:
```swift
case .newAction(let parameter):
    let result = await apiService.call(parameter)
    return [.actionCompleted(result)]
```

### Добавление нового сервиса

1. Создать протокол:
```swift
protocol NewServiceProtocol {
    func doSomething() async throws -> Result
}
```

2. Реализовать сервис:
```swift
final class NewService: NewServiceProtocol {
    func doSomething() async throws -> Result {
        // implementation
    }
}
```

3. Зарегистрировать в `Configurator`:
```swift
ServiceLocator.shared.addService(service: NewService() as NewServiceProtocol)
```

4. Использовать через `@Injected`:
```swift
@Injected var newService: NewServiceProtocol
```

## 🔍 Логирование

Используйте `AppLogger` для всех логов:

```swift
AppLogger.action(action)                    // Логирование actions
AppLogger.stateChange("userId", nil, "123") // Изменения состояния
AppLogger.error("Failed to sync", error)    // Ошибки
```

Логи автоматически отключаются в Release builds.

### Пример логов
```
🎯 Action: checkAuth
🎯 Action: authCheckCompleted(deviceId: Optional("B7DDU4..."))
```

При миграции:
```
🎯 Action: checkAuth
🎯 Action: startMigration
🎯 Action: migrationCompleted(deviceId: "...", userId: "...")
🎯 Action: authCheckCompleted(deviceId: Optional("..."))
```

## 📱 Запуск проекта

1. Откройте `RedCalendar-Female.xcodeproj`
2. Выберите таргет и симулятор
3. Нажмите Run (⌘R)

### Тестирование миграции
Для тестирования миграции добавьте Firebase UID в keychain:
```swift
let keychain = KeychainService()
keychain.saveUserUID("nSJXOCPF3ocA4Znn1sL7KvI1dh13")
```

## 🧪 Тестирование

```bash
# Unit tests
cmd+U

# UI tests
cmd+shift+U
```

## 🎯 События аналитики

Отслеживаемые события:
- `user_login` - успешная авторизация
- `user_logout` - выход из аккаунта
- `migration_completed` - успешная миграция с Firebase
- `migration_failed` - ошибка миграции
- `app_error` - системные ошибки

## 🚧 Roadmap

### Ближайшие задачи
- [ ] **CRUD операции** для циклов и данных
- [ ] **Push уведомления** через APNs
- [ ] **Синхронизация данных** с бэкендом
- [ ] **Верификация device_id** на сервере

### Будущие улучшения
- [ ] **Biometric авторизация** (Face ID / Touch ID)
- [ ] **SSL Pinning** для API запросов
- [ ] **Offline mode** с локальным кэшированием
- [ ] **Widget Extension** для iOS

## 🤝 Вклад в проект

1. Следуйте архитектурным принципам Redux
2. Все side effects только в middleware
3. Используйте протоколы для сервисов
4. Добавляйте логирование через AppLogger
5. Пишите тесты для новой функциональности

## 📄 Лицензия

Proprietary - Все права защищены

---

**Автор**: Артём Болотов  
**Версия**: 4.0.0  
**Дата**: 05.06.2025

## 📈 Changelog v4.0.0

### ✅ Добавлено
- **Автоматическая миграция** с Firebase на собственную систему авторизации
- **APIService** для взаимодействия с https://api.calendar.red
- **MigrationMiddleware** для обработки миграции пользователей
- **Поддержка async/await** в middleware архитектуре
- **Расширенная система состояний** (checking, migrating, authenticated, notAuthenticated)

### 🔄 Изменено
- **KeychainService** теперь поддерживает и device_id и user_uid
- **AppState** использует device_id как основной токен авторизации
- **AuthMiddleware** проверяет device_id с приоритетом над user_uid
- **Упрощен HomeView** - убрана избыточная отладочная информация

### 🚀 Миграция готова к продакшену
Система автоматически переведет всех пользователей с Firebase Auth на собственную систему авторизации без потери данных.
