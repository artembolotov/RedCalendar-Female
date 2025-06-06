# RedCalendar API

API сервер для приложения **RedCalendar** - облачного трекера менструального цикла для iOS.

## О проекте

RedCalendar мигрирует с Firebase на собственную серверную инфраструктуру в связи с новыми требованиями российского законодательства. Приложение переписывается с UIKit на SwiftUI с собственной системой авторизации и уведомлений.

## Архитектура

### Backend
- **Node.js + Express.js** - основной API сервер
- **PostgreSQL** - база данных пользователей и циклов
- **Connection Pool** - оптимизированное управление соединениями с БД
- **SSL/TLS** - зашифрованные соединения с базой данных
- **Firebase UID генератор** - совместимость с существующими идентификаторами

### iOS приложение
- **SwiftUI** - современный UI framework
- **Redux архитектура** - предсказуемое управление состоянием
- **Dependency Injection** - ServiceLocator с `@Injected` property wrapper
- **Keychain** - безопасное хранение авторизационных данных
- **AppMetrica** - аналитика (Яндекс)

## Структура проекта

```
RedCalendar/
├── app/                          # Backend API сервер
│   ├── hello.js                  # Основной сервер Express.js
│   ├── package.json              # Зависимости и конфигурация
│   ├── app.log                   # Логи приложения
│   ├── services/                 # Сервисы
│   │   ├── database.js           # PostgreSQL connection pool
│   │   ├── auth.js               # Сервис авторизации и миграции
│   │   ├── logger.js             # Система логирования
│   │   └── firebase-uid.js       # Генератор Firebase-совместимых UID
│   ├── api/                      # API маршруты
│   │   └── auth.js               # POST /auth/migrate, GET /auth/verify
│   ├── .eslintrc.js              # Конфигурация линтера
│   └── .eslintignore             # Исключения для ESLint
├── RedCalendar-Female/           # iOS приложение
│   ├── App/                      # Основные файлы приложения
│   │   ├── RedCalendar_FemaleApp.swift
│   │   └── Configurator.swift    # Настройка DI контейнера
│   ├── Core/                     # Базовая архитектура
│   │   ├── DI/                   # Dependency Injection
│   │   │   ├── ServiceLocator.swift
│   │   │   └── Injected.swift    # @Injected property wrapper
│   │   ├── Redux/                # Redux архитектура
│   │   │   ├── Store.swift       # Основной Store
│   │   │   ├── States/           # State модели
│   │   │   ├── Actions/          # Action модели
│   │   │   ├── Reducers/         # Reducers
│   │   │   └── Middleware/       # Middleware для async операций
│   │   ├── Services/             # Бизнес-логика
│   │   │   ├── AnalyticsService.swift
│   │   │   ├── KeychainService.swift
│   │   │   └── APIService.swift
│   │   └── Utils/
│   │       └── Logger.swift      # Логирование
│   ├── Features/                 # Функциональные модули
│   │   ├── Auth/Views/           # Авторизация
│   │   └── Home/Views/           # Главный экран
│   └── Common/Views/             # Общие компоненты
├── .github/workflows/            # CI/CD
│   └── netangels.yml             # Автодеплой на NetAngels
└── База данных RedCalendar - Документация.md
```

## API методы

| Метод | Путь | Описание |
|-------|------|----------|
| `GET` | `/` | Информация о сервере и доступных маршрутах |
| `GET` | `/health` | Проверка состояния сервера и базы данных |
| `POST` | `/auth/migrate` | **Миграция с Firebase UID на device_id** |
| `GET` | `/auth/verify` | Проверка валидности device_id |

## Авторизация

### Миграция с Firebase

API предоставляет плавную миграцию с Firebase Auth на собственную систему:

```bash
# Миграция пользователя
curl -X POST https://api.calendar.red/auth/migrate \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "nSJXOCPF3ocA4Znn1sL7KvI1dh13",
    "device_model": "iPhone 15 Pro"
  }'
```

**Ответ:**
```json
{
  "success": true,
  "data": {
    "device_id": "abc123def456ghi789jkl012mno345",
    "user_id": "nSJXOCPF3ocA4Znn1sL7KvI1dh13"
  },
  "message": "Migration completed successfully",
  "timestamp": "2025-06-05T10:30:00.000Z"
}
```

### Логика работы

1. **Старое приложение** сохраняет `user_uid` в keychain
2. **Новое приложение** ищет в keychain:
   - Если есть `device_id` → использует его
   - Если есть только `user_uid` → вызывает `/auth/migrate`
   - Получает `device_id` и сохраняет в keychain
3. **Все запросы** используют `device_id` в заголовке `Authorization: Bearer {device_id}`

### Проверка авторизации

```bash
# Проверка device_id
curl -X GET https://api.calendar.red/auth/verify \
  -H "Authorization: Bearer abc123def456ghi789jkl012mno345"
```

## iOS архитектура

### Dependency Injection

Система основана на ServiceLocator с элегантным `@Injected` property wrapper:

```swift
// Регистрация сервисов при старте
func setup() {
    let analytics: AnalyticsServiceProtocol = AnalyticsService()
    ServiceLocator.shared.addService(service: analytics)
    
    let keychain: KeychainServiceProtocol = KeychainService()
    ServiceLocator.shared.addService(service: keychain)
    
    let apiService: APIServiceProtocol = APIService()
    ServiceLocator.shared.addService(service: apiService)
}

// Использование в коде
class SomeClass {
    @Injected var analytics: AnalyticsServiceProtocol
    @Injected var keychain: KeychainServiceProtocol
    
    func doSomething() {
        analytics.trackEvent("action_performed")
        keychain.saveDeviceID("device123")
    }
}
```

### Redux State Management

```swift
// Actions
enum AppAction {
    case checkAuth
    case startMigration
    case migrationCompleted(deviceId: String, userId: String)
    case login
    case logout
}

// State
struct AppState {
    var isAuthenticated: Bool { deviceId != nil }
    var authCheckState: AuthCheckState { /* computed */ }
    var deviceId: String?
    var userId: String?
}

// Usage
@EnvironmentObject var store: AppStore
store.send(.checkAuth)
```

### Middleware Architecture

Асинхронная обработка через middleware:

```swift
let authMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    
    switch action {
    case .checkAuth:
        if let deviceId = keychain.getDeviceID() {
            return [.authCheckCompleted(deviceId: deviceId)]
        }
        if let userId = keychain.getUserUID() {
            return [.startMigration]
        }
        return [.authCheckCompleted(deviceId: nil)]
    }
    return []
}
```

## База данных

### Подключение PostgreSQL (NetAngels)
- **Host**: postgres.c107255.h2
- **Database**: c107255_api_calendar_red
- **User**: c107255_api_calendar_red
- **SSL**: Включен с `rejectUnauthorized: false` (самоподписанный сертификат)
- **Connection Pool**: max 10 соединений

### Структура базы данных
Таблицы создаются автоматически при первом запуске приложения:
- `users_female` - пользователи-женщины
- `user_devices` - устройства для авторизации и push-уведомлений
- `cycles` - данные о менструальных циклах
- `comments` - комментарии к дням
- `user_tags` - пользовательские теги
- `day_tags` - связь тегов с днями
- `notification_schedule` - расписание уведомлений

### Структура авторизации

- **Firebase UID** → `users_female.id` (VARCHAR(50))
- **Device ID** → `user_devices.device_id` (VARCHAR(50), Firebase-style UID)
- **Foreign Keys** → все связи настроены с CASCADE DELETE

Подробная схема БД: [База данных RedCalendar - Документация.md](База%20данных%20RedCalendar%20-%20Документация.md)

## Установка и запуск

### Backend
```bash
# Переход в папку приложения
cd app

# Установка зависимостей
npm install

# Запуск в режиме разработки
npm run dev

# Запуск в продакшен режиме
npm start
```

### iOS
1. Открыть `RedCalendar-Female.xcodeproj` в Xcode
2. Выбрать target `RedCalendar-Female`
3. Запустить на симуляторе или устройстве

### Переменные окружения
```bash
# Опционально
APP_IP=127.0.0.1        # IP адрес сервера (по умолчанию 127.0.0.1)
APP_PORT=3000           # Порт сервера (по умолчанию 3000)
NODE_ENV=production     # Окружение для production настроек
```

## Проверка кода

### Backend
```bash
# Проверка синтаксиса и стиля кода
npm run lint

# Автоматическое исправление ошибок
npm run lint:fix

# Запуск тестов (включает lint)
npm test
```

### iOS
- Используется встроенный Swift Compiler
- Проверка архитектуры через Xcode Analyzer
- Unit тесты (планируются)

### Настройки ESLint
- **Критические ошибки**: `no-undef`, `no-unused-vars`, `no-unreachable`, `semi`
- **Предупреждения**: `quotes`, `prefer-const`
- **Разрешено**: `console.log` в серверном коде

## Деплой

### Автоматический деплой на NetAngels
При пуше в ветку `master` запускается GitHub Actions:

1. **Test** - ESLint проверка и тесты кода
2. **Deploy** - FTP загрузка файлов на сервер
3. **Install** - установка зависимостей (`npm ci --production`)
4. **Restart** - перезапуск сервера через `touch ../reload`
5. **Health check** - проверка работоспособности API

**Production URL**: https://api.calendar.red

### Секреты GitHub Actions
```
FTP_SERVER      # FTP сервер NetAngels
FTP_USERNAME    # FTP логин
FTP_PASSWORD    # FTP пароль
SSH_HOST        # SSH хост
SSH_USERNAME    # SSH логин  
SSH_PASSWORD    # SSH пароль
SSH_PORT        # SSH порт
```

## Безопасность

### Backend
- **CORS** настроен для всех источников (для разработки)
- **SSL/TLS** соединения с PostgreSQL
- **Connection pooling** с таймаутами
- **Graceful shutdown** с корректным закрытием соединений
- **Error handling** без раскрытия внутренней информации
- **Транзакции** для атомарности операций
- **Параметризованные запросы** для защиты от SQL injection
- **Логирование** только в файл, без вывода через API

### iOS
- **Keychain** для хранения user_uid/device_id
- **SSL Pinning** (планируется)
- **Biometric Authentication** (планируется)
- **Type Safety** через Swift и Dependency Injection

## Логирование

### Backend логи
- **Файловое логирование** - все логи сохраняются в `app/app.log`
- **Ротация логов** - автоматическое создание `app.log.1`, `app.log.2` при превышении 1MB
- **Структурированные логи** - timestamp, уровень, сообщение
- **Безопасность** - логи не доступны через API, только через SSH

### iOS логи
```swift
// Использование AppLogger
AppLogger.action(action)  // Логирование Redux actions
AppLogger.error("Migration failed", error: error)
AppLogger.stateChange("deviceId", oldValue: nil, newValue: "abc123")
```

### Анализ логов
```bash
# Просмотр последних логов
tail -f /home/c107255/api.calendar.red/app/app.log

# Поиск ошибок
grep "ERROR" /home/c107255/api.calendar.red/app/app.log

# Анализ миграций
grep "Migration" /home/c107255/api.calendar.red/app/app.log
```

## Мониторинг

### Health checks
- `GET /health` - состояние сервера и базы данных
- Логирование всех операций в файл `app.log`
- Мониторинг через SSH доступ к серверу

### Метрики
- Connection pool utilization
- Response times
- Error rates
- Database query performance
- Migration success rate

## Миграция с Firebase

### Этапы миграции
1. ✅ **Backend API** - базовая структура сервера
2. ✅ **Database schema** - схема PostgreSQL
3. ✅ **iOS Redux** - архитектура управления состоянием
4. ✅ **Auth system** - миграция с Firebase Auth на собственную систему
5. ✅ **Dependency Injection** - ServiceLocator + @Injected
6. ✅ **Production ready** - убраны все тестовые endpoint'ы
7. 🔄 **Data migration** - перенос данных из Firestore
8. 🔄 **Push notifications** - замена FCM на APNs
9. 🔄 **Analytics** - интеграция с AppMetrica

### Совместимость
- **Firebase UID** сохраняются при миграции
- **Device ID** генерируются в Firebase-style формате (28 символов, base62)
- **Daystamp система** для эффективного хранения дат
- **JSONB поля** для гибкого хранения настроек и данных

## Технологии

### Backend
- **Node.js 24.1** - серверная платформа
- **Express.js 4.21** - веб-фреймворк
- **pg 8.16** - PostgreSQL драйвер с connection pooling
- **ESLint 8.57** - линтер кода
- **crypto** - генерация Firebase-совместимых UID

### iOS
- **SwiftUI** - декларативный UI framework
- **Foundation** - базовые API
- **Security** - Keychain Services
- **UIKit** - совместимость с системными API
- **AppMetricaCore** - аналитика от Яндекс

### DevOps
- **GitHub Actions** - CI/CD pipeline
- **NetAngels** - shared hosting
- **ESLint** - контроль качества кода

## Текущий статус

### ✅ Реализовано
- Базовая структура API сервера
- Подключение к PostgreSQL БД
- Миграция пользователей с Firebase UID на device_id
- Система авторизации через device_id
- iOS Redux архитектура с полным state management
- Dependency Injection система с @Injected property wrapper
- Keychain сервис для безопасного хранения данных
- API сервис для взаимодействия с backend
- Автоматический деплой через GitHub Actions
- Система логирования в файл
- Firebase-совместимый генератор UID
- Production-ready код без тестовых endpoint'ов

### 🔄 В разработке
- CRUD операции для циклов, комментариев, тегов
- Push notifications через APNs
- Перенос данных из Firebase
- UI компоненты календаря и трекера

### 📋 Следующие шаги

1. **User data endpoints** - CRUD операции для циклов, комментариев, тегов
2. **Calendar UI** - основной интерфейс трекера циклов
3. **Push notifications** - интеграция с APNs
4. **Data migration script** - перенос данных из Firebase
5. **Testing** - unit и integration тесты
6. **Documentation** - API документация в OpenAPI формате

## Тестирование

### Проверка API
```bash
# Проверка состояния сервера и БД
curl https://api.calendar.red/health

# Тест миграции пользователя
curl -X POST https://api.calendar.red/auth/migrate \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "nSJXOCPF3ocA4Znn1sL7KvI1dh13",
    "device_model": "iPhone 15 Pro"
  }'

# Проверка авторизации
curl -X GET https://api.calendar.red/auth/verify \
  -H "Authorization: Bearer {полученный_device_id}"
```

### Диагностика проблем
```bash
# Просмотр логов сервера через SSH
ssh c107255@ssh.c107255.h2
tail -f /home/c107255/api.calendar.red/app/app.log

# Поиск ошибок в логах
grep "ERROR\|Migration error\|Database.*error" app.log

# Проверка состояния процессов
ps aux | grep node
```

---

**Автор**: Артём Болотов  
**Версия**: 2.1.0  
**Последнее обновление**: 06.06.2025

## Изменения в версии 2.1.0

### iOS архитектура
- ✅ Реализована полноценная Redux архитектура с Store, Actions, Reducers, Middleware
- ✅ Добавлена система Dependency Injection с ServiceLocator и @Injected property wrapper
- ✅ Создан KeychainService для безопасного хранения учетных данных
- ✅ Реализован APIService для взаимодействия с backend API
- ✅ Добавлены middleware для обработки авторизации, миграции и аналитики
- ✅ Настроена система логирования для iOS приложения

### Backend
- ✅ Убраны все тестовые endpoint'ы (`/hello`, `/testdb`, `/auth/debug`, `/logs`)
- ✅ Добавлена проверка БД в `/health` endpoint
- ✅ Логирование только в файл `app.log` без вывода через API
- ✅ Повышена безопасность - никакой внутренней информации через API
- ✅ Production-ready код готовый к развертыванию

### Архитектурные улучшения
- ✅ Элегантный `@Injected` property wrapper с lazy инициализацией
- ✅ Type-safe dependency injection
- ✅ Предсказуемое управление состоянием через Redux
- ✅ Асинхронная обработка через middleware
- ✅ Полная интеграция iOS приложения с backend API
