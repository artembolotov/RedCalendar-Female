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
- `AppState` is `Equatable`; the store skips the `@Published` write when the reducer
  returns an identical state (`isDuplicate: (==)` in the app entry point), so no-op
  actions don't invalidate views. Keep new state types `Equatable`. Untyped `Error`
  payloads (`AuthState.migrating`, `EmailAuthState.entry`) compare by
  `localizedDescription` — that's the observable identity for the UI.

**Adding a new action:** add a case to `AppAction`, handle it in `appReducer`, handle side effects in the relevant middleware file.

**Adding a new middleware:** create `*Middleware.swift` in `Core/Redux/Middleware/`, register it in `combineAppMiddlewares()` in `Core/Redux/AppMiddleware.swift`.

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
  Constants.swift
  DI/         — ServiceLocator, @Injected
  Models/     — Daystamp, AuthenticationMethod, AuthenticationError,
                 APNSToken, UserDetails, DayDisplayState,
                 CycleRecord, CycleRecord+Queries,
                 CommentRecord, UserTagRecord, DayTagsRecord
  Redux/
    Actions/  — AppAction
    Middleware/
      AuthMiddleware.swift
      MigrationMiddleware.swift
      DatabaseMiddleware.swift
      PushNotificationsMiddleware.swift
      AnalyticsMiddleware.swift
      FeedbackMiddleware.swift
      LoggerMiddleware.swift
    Reducers/ — AppReducer, DayDisplayStateComputer
    States/   — AppState, AuthState, CalendarState,
                 EmailAuthState, PhoneAuthState, NotificationState
    AppMiddleware.swift  — combineAppMiddlewares()
    AppStore.swift       — typealias AppStore = Store<AppState, AppAction>
    Store.swift          — generic Store<State, Action>
  Services/   — APIService, KeychainService, AnalyticsService,
                 PushPermissionService, TapticFeedbackService,
                 DatabaseService (GRDB)
  Utils/      — Logger (AppLogger)
Common/
  Components/ — PrimaryButton, PhoneNumberKitField, FlowLayout
  Extensions/ — Bundle+AppInfo, String+Validation, View+AdaptiveShadow, …
  Modifiers/  — FormFieldStyle
  Views/      — RootView, WaitingView
Features/
  Auth/
    Views/
      WelcomeView, LoginView
      EmailAuth/ — EmailEntryView, CodeEntryView
      PhoneAuth/ — PhoneEntryView, FlashCallCodeEntryView
  Home/
    Calendar/
      CalendarView
      Components/ — CalendarHeaderView, InfiniteScrollContainer
      Models/     — CalendarModels, CalendarConstants,
                     MonthCalculator, ScrollCommand, ViewportCalculator
    Components/   — FloatingAddButton, HomeMenuView
    HomeView, DayDetailsView, FloatingButtonState,
    CommentSheetView, TagsSheetView
  Settings/   — SettingsView
  Statistics/ — StatisticsView
```

Feature folders own their own views and feature-specific models. Shared types go in `Core/Models/`.

## Key Patterns

### AppState

`AppState` has four top-level fields:

```swift
struct AppState {
    var authState: AuthState?          // nil until first auth check completes
    var calendarState: CalendarState   // always present, reset on logout
    var notifications: NotificationState
    var analyticsActivated: Bool
}
```

Convenience computed properties (`isAuthenticated`, `deviceId`, `currentUser`) are defined in an extension. Use them when reading a single value:

```swift
if let deviceId = store.state.deviceId { … }
```

Use direct pattern-matching only when you need multiple associated values at once:

```swift
if case .authenticated(let deviceId, let userDetails) = state.authState { … }
```

### AuthState

`AuthState` is an enum stored in `AppState.authState` (optional — `nil` means the initial check hasn't run yet). Cases:

```swift
enum AuthState {
    case notAuthenticated
    case authenticated(deviceId: String, userDetails: UserDetails?)
    case migrating(userId: String, error: Error? = nil)
    case authenticating(AuthenticationMethod)
}
```

`CalendarState` is a **top-level** field on `AppState` — not inside `AuthState`. Mutate it directly in the reducer:

```swift
case .setSelectedDayStamp(let dayStamp):
    state.calendarState.selectedDayStamp = dayStamp
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

### Cycle Domain Logic

All cycle queries live in `Core/Models/CycleRecord+Queries.swift` as an extension on `[CycleRecord]`:
`owningCycle(for:)`, `ongoingCycle(covering:)`, `completedCycle(covering:)`,
`canStartPeriod(at:today:)`, `canEndPeriod(at:today:)`, `predictedCycleStart(for:defaultLength:)`,
plus `flowLevel(on:)` / `setFlowLevel(_:on:)` and `predictedCycleStart(for:defaultLength:)` on
`CycleRecord`.
**Never re-implement these searches inline** (in views, middleware, or reducers) — validation and
display must always agree.

**No editing the future:** a period can be started or ended only on a day that has already come —
both `canStartPeriod` and `canEndPeriod` reject `day > today`. Actions that *clear* data
(toggling a start off, `unmarkPeriodEnd`) stay allowed for future days so records synced from
another device can be undone.

**Sorted invariant:** `CalendarState.cycles` is sorted by `startDay` ascending — the reducer sorts
once in `.setCycles`, and the queries are early-exiting backward scans that rely on that order.
Never store an unsorted cycle array in state.

When a view needs several lookups for one day, resolve them once per render with
`cycles.dayContext(for:)` (`CycleDayContext`) instead of calling the individual queries from
multiple computed properties.

Fallback cycle settings (cycle length 28, period 5, luteal phase 14) are in `Constants.Cycle` — do not
hardcode the numbers.

`CalendarState.dayDisplayStates` is **sparse**: it is recomputed by `computeDayDisplayStates`
(`Core/Redux/Reducers/DayDisplayStateComputer.swift`) in the reducer whenever cycle/tag/comment/range
state changes, and only days with content get an entry. A missing key means `DayDisplayState.empty` —
readers must treat absence as "nothing to show", never assume every day in `loadedRange` has an entry.

`CalendarState.loadedRange` is centered on the viewport: `CalendarView` dispatches
`.calendarScrolledTo(center:)` as the user scrolls, and `DatabaseMiddleware` re-centers the range
(and its comment/tag observations) when the center gets close to an edge. Buffer and threshold live
in `Constants.Calendar` — do not hardcode them.

### API Service

- Base URL comes from `Info.plist` key `API_BASE_URL`, set per build configuration. Read it via `Constants.URLs.api`.
- All API methods are on `APIServiceProtocol`. Add new endpoints to the protocol first, then implement in `APIService`.
- Request/response models are `Codable` structs defined in `APIService.swift`. Use `snake_case` CodingKeys where the API differs from Swift conventions.
- Auth header: `"Bearer \(deviceId)"`.
- Language header (`X-App-Language`) is added to endpoints that return localised messages.
- `validateHTTPResponse(_:data:)` is the single error-handling choke point — do not duplicate HTTP status checking.

### Database (GRDB)

Local storage uses GRDB with `DatabaseQueue` (file in Application Support). All database access goes through `DatabaseServiceProtocol`.

**Record types** (`Core/Models/`):
- `CycleRecord` — cycle start days, period length, ovulation, flow levels
- `CommentRecord` — per-day text comments
- `UserTagRecord` — user-defined tags (symptoms, moods, etc.)
- `DayTagsRecord` — which tags are assigned to which days

All records conform to `Codable, FetchableRecord, PersistableRecord`. Column mapping uses `enum Columns: String, CodingKey, ColumnExpression` with `typealias CodingKeys = Columns` for snake_case column names.

**Soft deletes:** records are not physically deleted. Instead, the main payload field is set to `nil` (`periodLength`, `comment`, `name`). Fetch methods filter out soft-deleted records (`WHERE field IS NOT NULL`).

**Equatable** is implemented without `updatedAt` — used by `ValueObservation.removeDuplicates()` to avoid spurious UI updates. `DayTagsRecord` compares `tagIds` as `Set`.

**Observations** return `AnyDatabaseCancellable` — the caller must retain the token to keep the observation alive.

**Migrations** are in `DatabaseService.runMigrations(_:)`. Always append new migrations — never modify existing ones.

### Environments

| Scheme | Config | API |
|---|---|---|
| RedCalendar-Female (Debug) | Debug | Dev |
| RedCalendar-Female (Release) | Release | Production |
| Staging Debug | Debug-Staging | Staging |
| Staging Release | Release-Staging | Staging |

`#if DEBUG` maps to both Debug and Debug-Staging — use it for `isDevelopment` flags (e.g., APNs sandbox).

## Swift & SwiftUI Style

- **SwiftUI only** for UI. `UIViewRepresentable` wrappers are allowed when SwiftUI has no equivalent (e.g., window-level gesture recognizers, third-party components); keep them isolated in dedicated files.
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
- **GRDB** 7.x — local SQLite database. All database calls go through `DatabaseServiceProtocol`.

Do not add new SPM packages without a clear reason.

## Git Workflow

- Always `git fetch origin` before comparing branches. Use `origin/main` (not local `main`) as the base:
  ```
  git fetch origin && git log --oneline origin/main..HEAD
  ```
  Local branch refs can be stale and produce false diffs.

## What's in Progress (v3.3)

- CRUD operations for user cycle data
- Tags and symptoms system
- Offline support with sync
- New API endpoint: `api.calendar.red`
- Day tap interactions (data entry from the calendar)
