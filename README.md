# RedCalendar
iOS приложение для отслеживания менструального цикла.

## Архитектура

### Redux/Flux
- **Store**: Единственный источник истины
- **Actions**: Все изменения через actions
- **Reducer**: Чистые функции, БЕЗ side effects
- **Middleware**: Вся асинхронная логика, возвращает `[Action]`

### Ключевые принципы
1. Reducer НИКОГДА не содержит side effects (no API calls, no Keychain)
2. Все side effects только в middleware
3. Middleware возвращает массив actions: `[Action]`
4. Computed properties вместо дублирования состояния
5. Все сервисы через протоколы и ServiceLocator

### Dependency Injection
```
@Injected var keychain: KeychainServiceProtocol
```

### Текущий функционал
- ✅ Проверка авторизации при запуске
- ✅ Хранение userId в Keychain
- ✅ Базовый flow: Login → Home

### Tech Stack
- SwiftUI (iOS 15.4+)
- Redux архитектура
- ServiceLocator для DI
- Миграция с Firebase на api.calendar.red
