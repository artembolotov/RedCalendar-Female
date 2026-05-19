# RedCalendar Female — Claude Guidelines

iOS app for menstrual cycle tracking. SwiftUI + Redux architecture. **iOS 15.4+, Xcode 16.4+, Swift 5.9+.**

## Architecture

### Redux

The app uses a hand-rolled Redux implementation.

**Core types** (`Core/Redux/`):
```swift
typealias Reducer<State, Action> = (State, Action) -> State
typealias Middleware<State, Action> = (State, Action, @escaping (Action) -> Void) async -> [Action]
```

**Rules:**
- `Store` is `@MainActor final class`. Never subclass or bypass `@MainActor`.
- Reducers are pure functions — no side effects, no async work inside them.
- All async work and API calls belong in middleware.
- Middleware returns `[Action]` for synchronous follow-up actions; use the `dispatch` closure for actions dispatched from within an async `Task`.
- State is always mutated by returning a modified copy from the reducer — never mutate state directly.
- All app state lives in `AppState`. Do not store state in views or view models.

**Adding a new action:** add a case to `AppAction`, handle it in `appReducer`, handle side effects in the relevant middleware file.

**Adding a new middleware:** create `*Middleware.swift` in `Core/Redux/Middleware/`, register it in `AppStore` initialization in `RedCalendar_FemaleApp.swift`.

### Dependency Injection

- `ServiceLocator.shared` is the DI container.
- All services are registered in `Configurator.setup()` as their **protocol type**, not the concrete type:
  ```swift
  let service: MyServiceProtocol = MyService()
  ServiceLocator.shared.addService(service: service)
  ```
- Inject services using `@Injected` inside middleware closures or class properties:
  ```swift
  @Injected var apiService: APIServiceProtocol
  ```
- Never call `ServiceLocator.shared.getService()` directly in views. Views read from the store only.

**Adding a new service:** create the protocol + implementation, register in `Configurator`, inject with `@Injected`.

### Project Structure

```
App/          — entry point, AppDelegate, Configurator
Core/
  DI/         — ServiceLocator, @Injected
  Models/     — shared data models (Daystamp, AuthState, UserDetails, …)
  Redux/      — Store, AppAction, AppState, reducers, middleware
  Services/   — APIService, KeychainService, etc.
  Utils/      — Logger
Common/       — reusable components, extensions, modifiers
Features/
  Auth/       — welcome, login, email auth, phone/Flash Call auth
  Home/       — main screen + integrated calendar (CalendarView, InfiniteScrollContainer, …)
  Settings/
  Statistics/
```

Feature folders own their own views and feature-specific models. Shared types go in `Core/Models/`.

## Key Patterns

### AuthState

`AuthState` is a nested enum stored in `AppState.authState`. The `.authenticated` case carries `deviceId`, `userDetails`, and `CalendarState`. Always pattern-match before reading nested state:

```swift
if case .authenticated(let deviceId, let userDetails, let calendarState) = state.authState { … }
```

When mutating nested calendar state in the reducer, unpack, mutate, repack:
```swift
if case .authenticated(let deviceId, let userDetails, var calendarState) = state.authState {
    calendarState.selectedDayStamp = dayStamp
    state.authState = .authenticated(deviceId: deviceId, userDetails: userDetails, calendarState: calendarState)
}
```

### Daystamp

`Daystamp` is the canonical type for calendar dates — use it instead of `Date` or `Int` wherever a "day" is the concept. Reference date is **January 1, 2001** (same as `TimeIntervalSinceReferenceDate` epoch for days).

```swift
let today = Daystamp.today(calendar: .current)
let tomorrow = today + 1
let range = today...(today + 30)
let date = today.toDate(calendar: .current)
```

Never compare calendar dates using `Date` directly — convert to `Daystamp` first.

### API Service

- Base URL comes from `Info.plist` key `API_BASE_URL`, set per build configuration. Read it via `Constants.URLs.api`.
- All API methods are on `APIServiceProtocol`. Add new endpoints to the protocol first, then implement in `APIService`.
- Request/response models are `Codable` structs defined in `APIService.swift`. Use `snake_case` CodingKeys where the API differs from Swift conventions.
- Auth header: `"Bearer \(deviceId)"`.
- Language header (`X-App-Language`) is added to endpoints that return localised messages.
- `validateHTTPResponse(_:data:)` is the single error-handling choke point — do not duplicate HTTP status checking.

### Environments

| Scheme | Config | API |
|---|---|---|
| RedCalendar-Female (Debug) | Debug | Dev |
| RedCalendar-Female (Release) | Release | Production |
| Staging Debug | Debug-Staging | Staging |
| Staging Release | Release-Staging | Staging |

`#if DEBUG` maps to both Debug and Debug-Staging — use it for `isDevelopment` flags (e.g., APNs sandbox).

## Swift & SwiftUI Style

- **SwiftUI only** for UI. Do not introduce UIKit views unless wrapping a third-party component that has no SwiftUI equivalent.
- Views read state via `@EnvironmentObject var store: AppStore` and dispatch actions via `store.send(…)`. No direct service calls in views.
- Local ephemeral UI state (`@State`) is fine for things like sheet presentation, drag offsets, animation state. Do not lift these into the Redux store.
- Use `MARK: -` sections: `// MARK: - Body`, `// MARK: - Private Methods`, etc., matching the existing files.
- Prefer `if case let` / `if case … =` pattern matching over `guard` with computed properties when destructuring enums.
- Errors conform to `LocalizedError` and implement `errorDescription`. Do not surface raw error messages to the UI — always use `AuthenticationError.from(_:)` to convert `APIServiceError` to a user-facing error.
- `AppLogger` (`Core/Utils/Logger.swift`) — use `.info`, `.warn`, `.error` instead of `print`.
- No comments explaining what the code does. Only add a comment when the **why** is non-obvious.

## External Dependencies (SPM)

- **AppMetrica** 5.11.1 — analytics & crash reporting. All analytics calls go through `AnalyticsServiceProtocol`.
- **PhoneNumberKit** 4.1.1 — phone number formatting and validation.

Do not add new SPM packages without a clear reason.

## What's in Progress (v3.3)

- CRUD operations for user cycle data
- Tags and symptoms system
- Offline support with sync
- New API endpoint: `api.calendar.red`
- Day tap interactions (data entry from the calendar)
