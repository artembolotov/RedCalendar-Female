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
   let authMiddleware: Middleware<AppState, AppAction> = { state, action in
       // Всегда возвращаем массив, даже если пустой
       return []
   }
   ```

4. **Computed properties вместо дублирования состояния**
   ```swift
   var isAuthenticated: Bool {
       userId != nil  // Вычисляется, а не хранится
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
│   │       ├── LoggerMiddleware.swift
│   │       └── AnalyticsMiddleware.swift
│   │
│   ├── DI/
│   │   ├── ServiceLocator.swift        # DI контейнер
│   │   └── Injected.swift              # Property wrapper
│   │
│   ├── Services/
│   │   ├── KeychainService.swift       # Безопасное хранение
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

- ✅ Проверка авторизации при запуске через Keychain
- ✅ Базовый auth flow: Login → Home
- ✅ Безопасное хранение userId в Keychain
- ✅ Централизованное логирование с AppLogger
- ✅ Интеграция AppMetrica для аналитики
- ✅ Dependency Injection через ServiceLocator

## 🛠 Tech Stack

- **UI**: SwiftUI (iOS 15.4+)
- **Architecture**: Redux/Flux
- **DI**: ServiceLocator + @Injected
- **Storage**: Keychain for secure data
- **Analytics**: AppMetrica
- **Backend**: Миграция с Firebase на api.calendar.red

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

## 📱 Запуск проекта

1. Откройте `RedCalendar-Female.xcodeproj`
2. Выберите таргет и симулятор
3. Нажмите Run (⌘R)

## 🧪 Тестирование

```bash
# Unit tests
cmd+U

# UI tests
cmd+shift+U
```

## 🤝 Вклад в проект

1. Следуйте архитектурным принципам
2. Все side effects только в middleware
3. Используйте протоколы для сервисов
4. Добавляйте логирование через AppLogger
5. Пишите тесты для новой функциональности

## 📄 Лицензия

Proprietary - Все права защищены

---

**Автор**: Артём Болотов  
**Версия**: 3.0.0
