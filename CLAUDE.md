# RedCalendar Female — Claude Guidelines

iOS app for menstrual cycle tracking. SwiftUI + Redux architecture. **iOS 15.4+, Xcode 26.4+, Swift 5.9+.**

## Architecture

### Redux

The app uses a hand-rolled Redux implementation.

**Core types** (`Core/Redux/AppStore.swift`):
```swift
typealias Reducer = (AppState, AppAction) -> AppState
typealias Dispatch = @MainActor @Sendable (AppAction) -> Void
typealias Middleware = @MainActor @Sendable (AppState, AppAction, @escaping Dispatch) async -> Void
```

**Rules:**
- `AppStore` is `@MainActor final class`. Never subclass or bypass `@MainActor`.
- **The store is concrete, not generic, and that is load-bearing.** `Store<State, Action>` had one
  instantiation and cost an archive: `swift-frontend` recursed without bound in `EarlyPerfInliner`
  on the generic class's implicit `deinit`, under `-O` only, so debug builds stayed green while
  every TestFlight upload failed. That is the history behind the shape; it is not a standing
  instruction to archive, only the thing to remember if anyone ever wants the generic back.
- Reducers are pure functions — no side effects, no async work inside them.
- All async work and API calls belong in middleware.
- **A dispatch is two halves: the reducer runs synchronously, the effects are queued.** `send`
  reduces on the caller's turn, so state changes in the order actions were sent and has already
  changed when `send` returns. The action is then appended to one queue that a single task drains
  in order, so one action's middleware chain finishes before the next one's begins. Middleware is
  handed the state *its own* action produced, not whatever the state has become by the time the
  queue reaches it.
- **A slow middleware is not free.** A long `await` in one delays every action behind it. That is
  affordable only because the heavy middlewares return immediately and do their work in their
  own `Task`, dispatching the result when it lands. Anything that waits on the network, on the
  user, or on a system alert belongs in a `Task` — see the permission prompt in `AuthMiddleware`.
  Short bounded work (`DatabaseMiddleware`'s GRDB writes) may be awaited inline.
- **Middleware is `@MainActor`.** It used to be an unisolated `async` closure, which put every
  middleware body on the cooperative pool and meant anything UIKit-shaped had to hop back by hand.
  Nothing that should leave the main actor is affected by the isolation: every such call is
  already `async` on an unisolated protocol (`APIService`, `PushPermissionService`,
  `DatabaseService`'s CRUD), and a `nonisolated async` function runs on the generic executor
  whatever actor called it. The corollary for new code is that a *synchronous* service call from
  middleware now blocks the main thread — `KeychainService` does, deliberately and rarely; make
  anything heavier `async` first.
- **A middleware that keeps state between actions must still declare where that state lives.**
  The serial queue means two actions no longer run their middleware concurrently, but that is
  scheduling, not ownership. `DatabaseMiddleware` owns GRDB observation tokens whose `deinit`
  cancels the observation, and it stays `@MainActor` for that reason; before it was isolated, a
  fast calendar scroll had two `.calendarScrolledTo` actions overwriting the same
  `AnyDatabaseCancellable` at once, which over-released it and crashed the app later, inside
  `malloc`, with nothing of ours on the stack. New stateful middleware needs the same treatment —
  isolation, not a lock.
- **A middleware emits actions one way: `dispatch`.** It returns `Void`. There used to be a second
  path — returning `[Action]` — and the two were indistinguishable in effect, since both ended in
  the same queue; what the return path bought was 15 `return []` statements in bodies that emit
  nothing. `dispatch` works the same from the body and from inside an async `Task`.
- State is always mutated by returning a modified copy from the reducer — never mutate state directly.
- All app state lives in `AppState`. Do not store state in views or view models.
- `AppState` is `Equatable, Sendable`; the store skips the `@Published` write when the reducer
  returns an identical state, so no-op actions don't invalidate views. Keep new state types
  `Equatable`. **Every error in the state tree is a concrete type** (`AuthState.migrating` carries
  `MigrationError`, `EmailAuthState.entry` carries `AuthenticationError`) — that is what the
  `Sendable` conformance enforces, and it is what lets `==` be synthesized. An `any Error` payload
  would bring back both the hand-written comparisons and the hole they papered over.

- **Actions are grouped by domain, and the grouping is what makes the compiler useful.** `AppAction`
  has one case per domain — `.auth`, `.calendar`, `.data`, `.push`, `.analytics`, `.appearance`,
  plus the cross-cutting `.retryFailedTasks` — each wrapping an enum of its own. Flat, every
  middleware ended in `default: break`, so a new case compiled everywhere and was handled nowhere:
  nothing told you that a new day-editing action had no middleware writing it to the database. A
  middleware that **owns** a domain now switches its sub-enum with no `default` (`AuthMiddleware`
  over `AuthAction`, `DatabaseMiddleware` over `DataAction`, and so on), and adding a case is a
  build error in the file that would have had to handle it. `DatabaseMiddleware` spells out the
  cases it deliberately ignores rather than sweeping them into a `default` — that list is the
  decision, not noise. The *outer* switch still takes a `default` and has to: every middleware sees
  every action, and a middleware that merely observes another domain (`FeedbackMiddleware` watching
  for almost everything, `MigrationMiddleware` watching for one auth case) matches what it wants
  and ignores the rest.

**Adding a new action:** add a case to the domain enum it belongs to in `AppAction.swift` — a new
top-level case is a claim that it belongs to no domain, which `retryFailedTasks` is currently the
only thing that can say. Then handle it in `appReducer` and in the middleware that owns the domain;
the compiler will name that middleware for you.

**A write that does not reach the disk is reported to the user, not only to the log.**
`DatabaseMiddleware.write` dispatches `.data(.writeFailed(DataWriteOperation))` on a failed
transaction, the reducer parks it in `CalendarState.writeFailure`, and `HomeView` presents it. It
holds one failure and the last one wins: these are single-row local transactions on a file the app
owns, so a failure means the store itself is in trouble and the second failure is the first one
again. The alert is presented from *state* rather than from a one-shot trigger, and from `HomeView`
rather than from the sheet that caused it — a comment is saved as its sheet dismisses, so the
failure lands while a presentation is already in flight, and a flag that stays true until answered
is the only version of this that survives that.

**Adding a new middleware:** create `*Middleware.swift` in `Core/Redux/Middleware/`, register it in `combineAppMiddlewares()` in `Core/Redux/AppMiddleware.swift`.

### Dependency Injection

- `ServiceLocator.shared` is the DI container.
- All services are registered in `Configurator.setup()` as their **protocol type**, not the concrete type:
  ```swift
  let service: MyServiceProtocol = MyService()
  ServiceLocator.shared.addService(MyServiceProtocol.self, service: service)
  ```
  The metatype argument is explicit, not inferred from `service`'s declared type — Swift's rule
  for binding a generic parameter from an existential-typed argument is not stable across language
  modes (see the Swift 6 note under Environments below), so `addService` takes the type it keys on
  as an ordinary value argument instead of leaving it to inference.
- Inject services using `@Injected` inside middleware closures or class properties:
  ```swift
  @Injected var apiService: APIServiceProtocol
  ```
- Never call `ServiceLocator.shared.getService()` directly in views. Views read from the store only.
- **Registration is launch-only and resolution is per-read.** `Configurator.setup()` is the one
  place that writes to the container; `@Injected` stores nothing and looks the service up on every
  read. Both sides take the container's lock, so resolving from any thread is safe — and the lock
  stays whatever the callers do: it makes safety a property of the type rather than of the order
  the container happens to be called in. Registering a service anywhere other than `setup()` is
  not a shortcut to avoid — it works — but it does mean thinking about what is reading the
  container at that moment.
- **Nothing may resolve a service at construction time.** The store's default value expression —
  `combineAppMiddlewares()` — runs before `RedCalendarApp.init()`'s body, which is where
  `Configurator.setup()` is called. Every service is therefore resolved lazily, on first use, long
  after registration. An eagerly-injected stored property anywhere in that chain is a `fatalError`
  on launch.
- The container keys on the type passed as `addService`'s first argument, which is what the
  protocol-type rule above is really enforcing: pass `MyService.self` and every
  `@Injected var x: MyServiceProtocol` misses.

**Adding a new service:** create the protocol + implementation, register in `Configurator`, inject with `@Injected`.

### Project Structure

```
App/          — entry point, AppDelegate, Configurator
Core/
  Constants.swift
  DI/         — ServiceLocator, @Injected
  Models/     — Daystamp, Daystamp+GRDB, AuthenticationMethod, AuthenticationError,
                 APNSToken, UserDetails, ResolvedCycleSettings, DayDisplayState,
                 AccentTheme, DataWriteOperation, UserProfileRecord,
                 SyncPayload, SyncStorage, JSONValue, DirtyStamped, FlowLevelRecord,
                 CycleRecord, CycleRecord+Queries,
                 CommentRecord, UserTagRecord, DayTagsRecord
  Redux/
    Actions/  — AppAction, plus the per-domain AuthAction/CalendarAction/DataAction/
                 SyncAction/PushAction/AnalyticsAction/AppearanceAction it wraps
    Middleware/
      AuthMiddleware.swift
      MigrationMiddleware.swift
      DatabaseMiddleware.swift
      SyncMiddleware.swift
      PushNotificationsMiddleware.swift
      AnalyticsMiddleware.swift
      AppearanceMiddleware.swift
      FeedbackMiddleware.swift
      LoggerMiddleware.swift
    Reducers/ — AppReducer, DayDisplayStateComputer
    States/   — AppState, AuthState, CalendarState, SyncState,
                 EmailAuthState, PhoneAuthState, NotificationState
    AppMiddleware.swift  — combineAppMiddlewares()
    AppStore.swift       — AppStore, plus the Reducer/Dispatch/Middleware typealiases
  Services/   — APIService, KeychainService, AnalyticsService,
                 PushPermissionService, TapticFeedbackService,
                 AppearanceService, DatabaseService (GRDB)
  Utils/      — Logger (AppLogger)
Common/
  Components/ — PrimaryButton, CloseButton, PhoneNumberKitField, FlowLayout
  Extensions/ — Bundle+AppInfo, String+Validation, View+AdaptiveShadow,
                 Color+AccentTheme, …
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
      Components/ — CalendarGridView, CalendarSelectionLayer, CalendarPalette,
                     CalendarHeaderView, CalendarTopChrome, InfiniteScrollContainer
      Models/     — CalendarModels, CalendarConstants, CalendarBandGeometry,
                     CalendarLayout, MonthCalculator, ScrollCommand, ViewportCalculator
    Components/   — FloatingAddButton, HomeMenuView
    HomeView, DayDetailsView, FloatingButtonState,
    CommentSheetView, TagsSheetView
  Settings/   — SettingsView
  Statistics/ — StatisticsView
```

Feature folders own their own views and feature-specific models. Shared types go in `Core/Models/`.

## Key Patterns

### AppState

`AppState` has nine top-level fields:

```swift
struct AppState {
    var authState: AuthState?          // nil until first auth check completes
    var calendarState: CalendarState   // always present, reset on logout
    var notifications: NotificationState
    var analyticsActivated: Bool
    var accentTheme: AccentTheme       // fallback until .checkAccentTheme lands
    var userProfile: UserDetails?      // the user_profile row's identity half
    var cycleSettings: ResolvedCycleSettings  // the same row's cycle half, resolved
    var syncState: SyncState           // what the sync indicator draws
    var emailBinding: EmailBindingState?      // the email binding/change screen, nil when closed
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
    case migrating(userId: String, error: MigrationError? = nil)
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
let daysApart = tomorrow - today        // Int, not Daystamp
for day in range { … }                  // ranges are iterable
let date = today.toDate(calendar: .current)
```

Never compare calendar dates using `Date` directly — convert to `Daystamp` first.

`Daystamp` is `Strideable` (stride `Int`), **not** `AdditiveArithmetic`: `day + Int` and
`day - Int` give a `Daystamp`, `day - day` gives a day count, and adding two daystamps is
deliberately not expressible. It is also `DatabaseValueConvertible`
(`Core/Models/Daystamp+GRDB.swift`), so day columns stay INTEGER and GRDB range filters
(`range.contains(Columns.dayNumber)`) work directly on `ClosedRange<Daystamp>`. Every day-typed
field — `CycleRecord.startDay`, `OvulationData.day`, `CommentRecord.dayNumber`,
`DayTagsRecord.dayNumber` — and every `DatabaseServiceProtocol` day range is a `Daystamp`.
Reach for `.rawValue` only for display or dictionary keys, never to do day arithmetic.

### Cycle Domain Logic

All cycle queries live in `Core/Models/CycleRecord+Queries.swift` as an extension on `[CycleRecord]`:
`owningCycle(for:)`, `ongoingCycle(covering:)`, `completedCycle(covering:)`,
`recordedPeriodCycle(covering:)`, `canStartPeriod(at:today:)`, `canEndPeriod(at:today:)`,
`canSetFlowLevel(at:today:)`, `predictedCycleStart(for:cycleLength:)`, plus `periodCoverage(of:)`,
`flowLevel(on:)` / `setFlowLevel(_:on:)`, `lastFlowDay(notAfter:)` and
`predictedCycleStart(for:cycleLength:)` on `CycleRecord`.
**Never re-implement these searches inline** (in views, middleware, or reducers) — validation and
display must always agree.

**One scan per day:** a day's period data always lives on the cycle that owns the day — no earlier
cycle can reach past a later cycle's start — so `owningCycle(for:)` plus
`CycleRecord.periodCoverage(of:)` answers every coverage question. Build new coverage queries on
those two; do not add another full-array scan.

**No editing the future:** a period can be started, ended, or given a flow level only on a day that
has already come — `canStartPeriod`, `canEndPeriod` and `canSetFlowLevel` all reject `day > today`.
Actions that *clear* data (toggling a start off, `unmarkPeriodEnd`) stay allowed for future days so
records synced from another device can be undone.

**Period data belongs to the recorded cycle:** write a day's end day or flow level against
`recordedPeriodCycle(covering:)` (`CycleDayContext.recorded`), never `owningCycle(for:)` — the
owning cycle also matches days long after its period ended and days inside a merely predicted
cycle, so the write would land on whichever real cycle came last.

**An open period is never confirmed:** for a cycle with `periodLength == 0` only the start day
renders confirmed — every later day stays predicted, because nothing except `markPeriodEnd` ends a
period. Logged flow only *lengthens* the forecast: the drawn length is
`max(periodLength, lastFlowDay(notAfter:) - startDay + 1)`, so flow on day 6 stretches the
bar to six days while flow on day 3 leaves the five-day forecast alone. Never shorten an open
period to its flow data or mark those days confirmed — that reads as a period the user finished.

A **completed** period is the opposite: every one of its days up to and including today renders
confirmed. Only days genuinely in the future stay faded.

**Sorted invariant:** `CalendarState.cycles` is sorted by `startDay` ascending — the reducer sorts
once in `.setCycles`, and the queries are early-exiting backward scans that rely on that order.
Never store an unsorted cycle array in state.

When a view needs several lookups for one day, resolve them once per render with
`cycles.dayContext(for:)` (`CycleDayContext`) instead of calling the individual queries from
multiple computed properties.

**A recorded cycle is never predicted over.** Extrapolation from the default cycle length only
applies past the *last* recorded start: once the next cycle is marked, that cycle's real length is
the distance between the two starts, so `CycleDayContext.predictedCycleStart(cycleLength:)` returns
nil for its days and the day-details subtitle shows the plain actual day ("30 день цикла", never
"30 (2)"). `computeDayDisplayStates` follows the same rule by construction — it synthesizes
predicted cycles only after `lastStartDay` and clips every cycle's segment at the next start.

**Cycle settings are never read raw.** `UserSettings.CycleSettings` carries unvalidated optional
integers straight from the API — a zero cycle length there divides by zero in `predictedCycleStart`
and never terminates the prediction loop in `computeDayDisplayStates`. Every reader takes
`AppState.cycleSettings`, which is `ResolvedCycleSettings`
(`Core/Models/ResolvedCycleSettings.swift`): clamped into the `Constants.Cycle` bounds, with the
fallbacks filled (cycle length 28, period 5, luteal phase 14). Fertile-window width also lives in
`Constants.Cycle` — do not hardcode any of these numbers.

**The profile row reaches the store as two actions, not one.** `.setUserProfile` carries the
identity half, `.setCycleSettings` the half the calendar draws with, and `DatabaseMiddleware`
dispatches both from the one observation. They are split because their owners are (§4.4) and
because their lifetimes are: `UserDetails` requires a `user_id`, which only the server writes, and
a settings edit made before the first successful sync run creates a row that has none. Folded
together, that edit would come straight back as `nil` and the number the user just chose would snap
to the fallback on screen. The settings are therefore read off `UserProfileRecord.settings`, never
off `UserDetails`.

**The settings screen is the first thing in this app that pushes a profile.** `SettingsView` edits
the cycle length and the period length, and the path it feeds — `.data(.setCycleLength/.setPeriodLength)`
→ `DatabaseMiddleware` → `DatabaseService.updateCycleSettings` → `user_profile.dirty_seq` →
`changes.profile` — was described and unused before it existed (SYNC.md §4.4, §15).

**The screen is a debounced editor, like the comment and tag sheets.** It holds its own draft
while the steppers are being tapped and dispatches once, after
`Constants.Sheets.autosaveDebounceNanoseconds` of quiet — plus on the close button (before the
dismissal, so the calendar underneath does not redraw a beat after the screen has gone) and on
`onDisappear`, for the swipe that never reaches the button. The intermediate values of a held
stepper are worth exactly what the intermediate values of a half-typed comment are worth, and
holding one from 28 to 90 is sixty-two taps — sixty-two GRDB writes, sixty-two stamped rows and
sixty-two sync triggers, for one intent. Because the draft lives in the view, nothing is reduced
ahead of the disk: `ResolvedCycleSettings` stays immutable, the reducer does not handle the two
edit actions at all, and a failed write has nothing to roll back.

Four rules hold the write path up, and each of them is a way to lose someone's data quietly:

- **The settings JSON is merged, never rebuilt.** `user_profile.settings_json` holds what the
  server sent, and the server replaces the column wholesale (`writeProfile` does
  `settings = $n::jsonb`). A local edit that re-encoded `UserSettings` would drop every key this
  build does not model — `predictions`, `notifications`, whatever comes next — and the first push
  would erase them on the server for every device. `JSONValue.setting(_:to:)` writes one path and
  leaves the rest alone.
- **An edit writes the key it changed and no other.** The screen shows a fallback for a value the
  user never chose; storing that fallback states a choice they did not make. Hence
  `CycleSettingsPatch`, and two actions rather than one carrying the pair.
- **`SyncProfilePush` omits a field it is not editing.** The server reads `changes.profile` by
  `hasOwnProperty`: `name: null` means *erase the name*, an absent `name` means *leave it alone*.
  Nothing edits the name, so nothing sends it — a device whose profile has not been pulled yet has
  no name to send, and sending its `nil` would delete the name given at registration everywhere.
  The type says this with a double optional (`String??`): `nil` is "not editing", `.some(nil)` is
  "erase".
- **A dirty profile holds back only the device's half of the row.** `applyPulled` applies
  `user_id`, `email` and `phone_number` whatever the flag says, because a device never writes them
  (§4.4's identity rule). Skipping the whole row while dirty — which is what every *table* does —
  would strand a device that edited its settings before the profile had ever been pulled: the
  cursor moves past that revision and `profile_revision > since` never matches again.

`updateCycleSettings` is also the only local writer that may **create** the `user_profile` row.
Nothing but a sync run has ever written it, so a user who is authenticated but has not yet had a
successful run has no row to edit; what it creates carries `sync_state`'s owner if there is one,
and no identity at all if there is not.

Four smaller consequences worth keeping:

- The clamp is a *presentation* decision until the user touches a stepper, and nothing may be
  written on appear. `settings` is checked for shape and not for contents (§4.5), so the column
  can hold any number a client ever wrote there; a value this build would clamp is still the value
  that person chose, and writing our version of it back is not ours to do. (Real profiles carry
  26–29 today — inside the bounds. The 19 in §4.5's table is an observed *interval between cycle
  starts*, which is a `CycleRecord` and not this setting.)
- `ResolvedCycleSettings` is constructed in one place only — the reducer, from what the profile
  observation delivered — and that is what makes clamping on the way in safe. A second
  construction path (an optimistic edit clamping a value the initialiser would clamp differently)
  is how the luteal phase, whose upper bound is a function of the cycle length, ends up
  disagreeing with the disk one round trip later.
- An edit that lands on the value already stored writes nothing. It is not free to write it
  anyway: the row is stamped dirty, a sync run is asked for, and a server revision is spent that
  every *other* device then pulls. Tapping + and back to − is enough to cause it.
- `JSONValue.jsonString` sorts its keys. A Swift dictionary iterates in a seed-randomised order,
  and `settings_json` is compared as a string by `UserProfileRecord.==` — which is the question
  `removeDuplicates()` asks of the profile observation.

**A brand-new email account is asked for these two numbers once, and nobody else is.**
`CycleOnboardingView` sits between a fresh email registration and `HomeView` — reached through
`AuthState.authenticated`'s `isFreshRegistration` flag, set by `AuthMiddleware` only from
`EmailAuthState.registering`, never from a returning login and never from phone. It reuses the
exact write path `SettingsView` does (`.data(.setCycleLength/.setPeriodLength)`), just once, on a
single "Продолжить" tap, with no debounce — there is nothing to coalesce when the whole screen is
one commit.

Phone sign-in never reaches it, because phone sign-in has no registration to begin with:
`checkPhone` answers `.phoneNotRegistered` for a number the server has never seen, since
RedCalendar 2.0 was phone-only. Every phone login is therefore an existing 2.0 account, and its
`settings` already crossed over verbatim in the Firebase import (§10.2 — `user.settings` →
`users_female.settings`, same shape) before this device ever pulled it; asking again would ask a
returning person to re-guess what they already told the old app.

This is the one place a write happens even when the person changes nothing. `SettingsView`'s "an
edit that lands on the stored value writes nothing" rule (above) protects an *existing* row from a
wasted revision — here there is no existing row for "unchanged" to mean anything against, and
tapping through with the defaults is the answer being asked for: it is what turns the silent 28/5
fallback into a value this person actually confirmed.

The flag lives only in this run's Redux state, not in the keychain or on the server. A force-quit
before the button is tapped lands on `HomeView` on the next cold launch — `.check` never sets
`isFreshRegistration` — showing the same fallback every build before this one already showed. That
gap is accepted, not fixed.

**Clearing the flag is its own action, not another `.set(.authenticated(...))`.** That pattern is
read by three other places as "the user just signed in": `SyncMiddleware` starts an undebounced
sync run on it, `AuthMiddleware` itself re-registers for remote notifications and can re-request
the push permission, and `DatabaseMiddleware` (re)starts its observations — guarded, but by a
check its own comment already flags as accidental ("nothing does today, but nothing enforces it").
`.auth(.completedRegistrationOnboarding)` reduces the flag off and triggers none of that.

**Two clips, and only one of them caps the bar.** In `computeDayDisplayStates` a period cut short by
the next cycle's start really does end there, so `SegmentPosition` is derived from that cut and the
last day caps with `.end` (or `.single`). `loadedRange` is a viewport, not a boundary: a period
running past it is clipped for drawing but keeps `.middle` at the edge, so the square end reads as
continuing offscreen. Never derive positions from the drawn range — that rounds off bars that merely
scrolled out of the loaded window. The fertile line obeys the same rule, with the cycle's own
segment as its real boundary: a cycle paints only the days it owns, so the window caps where the
cycle does — but a window running past `loadedRange` still keeps its square edge there.

**The fertile window is a line under the day, and it has a lane of its own.** It is a 2pt lilac
rule (`FertileWindow` → `CalendarGridView`'s Layer 1), drawn per day from `SegmentPosition` like
the period bar, so caps and row wraps follow identical rules — only genuine window caps round, a
run continuing onto the next calendar row is `.middle` there and stays flush. It keeps the
`RoundedCorners` per-corner shape where the bar has moved to a clipped `RoundedRectangle`: at a
1pt radius a continuous corner and a circular one are the same pixels, so the simpler construction
wins. Its radius is half its height, so the window's ends read as a capsule. The ovulation
day is a full-strength orange — a different hue, not a denser lilac. That distinction was once
carried by alpha alone, which worked while the window was a 26pt fill and stopped working the
moment it became a 2pt line: a step in density needs area to read, and a line has none.

**A prediction differs in form, not in density.** A predicted period is a *hollow* bar — a
`predictedBarStrokeWidth` outline in the accent red and nothing behind it — where a confirmed one
is solid; a predicted ovulation day is a dashed rule where a confirmed one is solid. The outline
needs no backing fill to group a run: it is drawn unbroken along the whole series and caps only at
its real ends, so the enclosure does the grouping. Never go
back to drawing either as an alpha of the confirmed colour: alpha over a background is a step in
lightness, and on a near-black background the only red dimmer than the confirmed red is a brown.
The outline carries the same meaning against white and against black. The day number follows the
bar — `Palette.predictedText` inside a hollow bar, white only inside a solid one; white on the old
faded fill was unreadable in the light theme.

**The bar's corners are `.continuous`, and that dictates how it is built.** A circular corner at
`periodBarCornerRadius` reads as a stamped rectangle; the continuous curve is what makes the bar
look drawn rather than cut. But continuous corners exist only on `RoundedRectangle`, which rounds
all four and has no per-corner API — so the bar cannot use `RoundedCorners`. Instead **both** the
solid and the hollow bar are drawn as one whole rounded rectangle, widened by
`periodBarCornerRadius * 2` on every side where the run continues and then clipped back to the
cell. The corners that must stay square land outside the clip, neighbouring days meet flush, and a
multi-day run has no internal seams. The overhang is sized off the radius, not the stroke width:
it has to clear the corner's full reach (~1.5x the radius), which also carries the predicted bar's
vertical stroke out of the clip. `strokeBorder` rather than `stroke` keeps that outline inside
`periodBarHeight`, where a plain `stroke` would straddle the edge and lose half its weight.

Do not raise the radius to half the height. At `periodBarHeight / 2` the bar becomes a pill and
starts competing with the day indicator's ⌀28 circle, which is the one shape in the cell that is
meant to read as round.

**Two reds would be one red too many.** The period bar, the today marker, the floating button and
the app tint are all `Color.accent` (the `AccentColor` asset). The calendar used to draw with the
system `Color.red` instead, and the two were visibly different next to each other.
`PredictedDayTextColor` is part of the same decision and moves with it: it is the day number inside
a hollow bar, so a hue that drifts from the accent puts the digit out of key with the outline it
sits in.

**The accent is chosen by the user, out of three.** `AccentTheme` (`Core/Models/AccentTheme.swift`)
has cases `coral`, `rose` and `berry`; each names two assets — the accent and the day number
inside a hollow bar — and the pair always moves together, because a predicted numeral off-hue from
the outline it sits in reads as a mistake. Coral keeps the unqualified asset names (`AccentColor`,
`PredictedDayTextColor`) since `AccentColor` is also the target's global accent and has to go on
carrying a real colour; the other two are suffixed. The choice lives in `AppState.accentTheme`,
is persisted to `UserDefaults` by `AppearanceService` through `AppearanceMiddleware`, and is
restored by `.checkAccentTheme` on launch — the store is constructed before any service is
reachable, so the initial value is always the fallback until that lands.

**An accent-derived colour is passed in, never read from the asset at the point of use.** There is
exactly one `.tint` in the app, on `RootView`, and everything merely tinted inherits it. Everything
that *fills* — the period bar, the today marker, the predicted outline, the floating button — takes
the colour as a parameter instead. Two consequences that are easy to get wrong: `CalendarGridView`
resolves the pair in its `init` rather than in a computed property (a named asset is a lookup, and
the grid touches it once per bar and once per numeral), and `theme` is part of its `Equatable`
conformance — leave it out and the grid keeps drawing the old accent until some unrelated input
changes. `HomeMenuView` takes the colour for the same reason it takes nothing else from the store:
it is toolbar content, where an `@EnvironmentObject` is not reliably reachable.

**UIKit gets the accent from the middleware, because SwiftUI's `.tint` does not reach it.** The
caret and selection handles in `PhoneNumberKitField`'s `UITextField` read `UIWindow.tintColor`, and
nothing about the modifier on `RootView` propagates into a `UIViewRepresentable`. So
`AppearanceMiddleware` writes the window tint on `.setAccentTheme` — the action that carries the
stored theme on launch and the chosen one afterwards, which is exactly when the answer changes.
This used to be one line in `AppDelegate` setting `UIWindow.appearance().tintColor` to the
`AccentColor` asset at launch, and it was wrong twice: it hardcoded coral whichever theme the user
had picked, before the stored one had even been read, and an appearance proxy is consulted when a
window is *created*, so choosing a different accent in settings could never change it. Both the
proxy and the live windows are written — the proxy for a window built later, the windows for the
one already on screen.

The auth screens follow the theme too. `PrimaryButton` takes a `Color` rather than an
`AccentTheme` — it lives in `Common` and has no business knowing what the app's themes are — and
each of the five auth views passes it from the store it already holds. The theme is a device
preference in `UserDefaults`, not user data, so it survives a logout: a returning user sees the
accent they picked on the welcome screen, before they have signed back in.

**Coral is the closest thing on screen to the ovulation orange.** `#D84831` / `#E46B58` sits at
~6°, off the 0–1° of the fire-engine red it replaced, and the dark variant drops from a fully
saturated 100% to 78% — that saturation was what made the old bar burn on the near-black page. The
cost of the warmth is hue clearance: the gap to `OvulationLineColor` is 29°, down from 36°, and it
is the tightest pairing in the palette. Rose (351°) and berry (345°) open it to 45° and 52°.
Anything new that wants a warm hue has to fit outside that pair, and moving either one toward the
other needs a check that the bar and the ovulation rule still read as different colours side by
side.

**White numerals on the bar are the ceiling on how bright any accent may go.** A day inside a solid
period renders `.white` in every theme, so an accent's luminance is squeezed from two sides:
contrast with that white text pulls it darker, separation from the near-black page pulls it
lighter. The trade is strict and hue-independent — at 5.0 against the dark page, 3.74 against white
is the most any hue can reach. Measured against white (light/dark) and against the page: coral
4.29/3.21 and 4.09/5.83, rose 4.84/3.55 and 4.61/5.27, berry 5.18/3.61 and 4.94/5.19. None of the
three clears the 4.5:1 that 16pt text formally wants on the dark side, and nothing vivid enough to
read as a period bar would. A fourth theme has to be placed on this same scale; do not brighten one
to make the bar pop without checking what it costs the numerals, and note that the honest fix for
the dark end is the numeral, not the red.

**The page background falls, and the indicator ring cannot follow it.** `LinearGradient.appBackground`
is a `AppBackgroundColor` → `AppBackgroundEdgeColor` vertical gradient that `HomeView` fills the
screen with, so the page does not read as a flat sheet. The ring around the today/selected circle is
what punches those circles out of a solid period bar, and it is drawn in the flat
`AppBackgroundColor` — it cannot sample the gradient under it. That only works because the two stops
are about four 8-bit levels apart: gradual across a whole screen, invisible across a 2pt ring.
Widening that gap puts a halo around every marked day at the bottom of the calendar; if the gradient
ever needs real range, the ring has to become a mask rather than a colour. The band's scrim makes
the same bet and would have to move with it.

It is a shared value because the calendar's top band draws it a second time. The band is opaque —
the page's own gradient at the page's own height, cropped to the band, with the blurred grid on top
— and that is what lets the sharp grid be drawn whole. It used to wear a gradient mask that was the
exact complement of the band's, so the two alphas summed to one; compositing an opaque band at alpha
`a` is the same crossfade (`a·blurred + (1-a)·sharp`) without a screen-sized offscreen pass on every
frame of a scroll. The band drawing the *actual* gradient rather than a flat stand-in is what keeps
it invisible over empty page, which is the whole reason it is not a `Material`. See
`CalendarView.blurredBandLayer`.

Three things are stacked below a cell's centre, in this order and no other: the day indicator
(⌀28, and ⌀28 + a 2pt outward ring when selected, so −15…+15), the fertile line (+18…+20) and the
dot row (+23…+29). The next week's own indicator starts at +39. The line sits *below* where the
period bar ends (±11) and *above* the dots on purpose — that is what keeps it clear of the period
bar entirely, so an overlapping cycle shows both, and what keeps a comment dot from crowding it.
The three gaps are 3pt each and there is nothing spare: move any one of the four constants in
`CalendarConstants` and the line lands under the selected day's circle or against the dots.

**The selection disc belongs to no day, which is what lets it move.** It is its own view
(`CalendarSelectionLayer`), stacked above the grid rather than drawn inside it, and a
numeral it covers is inverted *by the disc* — the row's numerals are drawn again in
`AppBackgroundColor` and revealed only through it — rather than by the cell's own state. That is
what makes a disc halfway between two days correct: cross-fading two cells' numerals instead would
wash both of them out at the midpoint, when the disc is over neither.

**Being a separate view is a performance decision as much as a visual one.** The disc lived inside
`CalendarGridView` first, which made `selectedDayStamp` one of the grid's inputs — so every day
tapped and every card swiped rebuilt several hundred day cells, in both copies of the grid, to move
one circle by a column. Split out, the grid does not know a selection exists and the two redraw on
entirely separate occasions. `CalendarView.gridLayer` stacks them so the pair still goes into both
copies with identical inputs. Never put `selectedDayStamp` back into the grid's inputs.

**The numerals do not travel; the hole does.** They are positioned in grid coordinates, in a strip
one disc tall, and the disc is the mask over it. Laying them out relative to the disc is smaller
code and was the first version of this, and it is wrong in motion: a view's content is built once
per body pass while only `.position` interpolates, so the disc carries the *destination's* digit for
the whole flight and leaves day 5 already showing a 6 — the number changing before the motion rather
than because of it. The strip's height is not incidental either. A mask is an offscreen pass over
the bounds it is given, and this one runs every frame of a flight; over the whole grid that is a
screen-sized buffer per frame to show a ⌀28 hole.

**It animates on one condition: that it can stay where it is on screen.** Within a row it can — the
calendar centres on the row, and the row has not changed — so the disc travels. A change of row is
the opposite case: the calendar flies to the new row, and whatever the disc does during that flight
is carried by a moving grid on top of its own motion. It reads as the disc falling into place rather
than being placed, in whichever direction the flight goes; a fade on the outgoing disc is worse
still, because the ghost rides the scroll. So a cross-row change is **instant** — no transition, and
no animated transaction for SwiftUI's default `.opacity` one to attach itself to.

That rule is carried by two pieces in `CalendarSelectionLayer`, and neither is optional. The animation
watches `marker.centerX` alone, so a move that changes the row cannot animate even when it changes
the column too; and the view's identity is the row, so such a move replaces it rather than reusing
it. Without the identity the disc flies the diagonal, without the narrow value it flies the
vertical. Do not widen the value to `selectedDayStamp` and do not wrap the disc in a container
`.animation` — either one hands the cross-row case an animated transaction again.

**Its short curve is tied to the day card's settle, by measurement.** A swipe across the card moves
both, so they have to land together: `SpringInterpolation` is normalized, so the card's
`settleDuration` of 0.55 at ζ=0.85 is a real decay of ~15.5 s⁻¹ and it arrives at ~0.25s (the rest
is the tail `CardPagingAnimator.onArrival` exists to ignore), against the disc's ~16.9 s⁻¹ and
~0.23s. Move one and check the other. What cannot be matched is the start — the card takes the
flick's velocity, the disc always leaves from rest. That is now a choice rather than a constraint:
the store reduces synchronously, so a `withAnimation` around a dispatch does reach the view, where
it used to be discarded with the deferred state change. Handing the gesture's velocity over would
mean choosing the animation at each call site, which is a change to how the disc moves and not a
number to tune here. Nothing in the app does it yet.

**Only a swipe slides the disc. A tap always places it, at any distance.**
`Animation.daySelection(travelDays:)` returns a curve for `travelDays == 1` and `nil` for
everything else — a jump across the week, and a first selection, which has nowhere to have come
from. ±1 is the only move a gesture makes, since the day card pages by exactly one day
(`DayDetailsPagerView.commit(shift:)`), so it is the only move where the disc follows something
the hand is already doing.

That leaves a tap on a *neighbouring* day, which is also one day and must not look like the swipe:
a disc sliding to a day the user already pointed at illustrates a journey nobody took. It is
suppressed by `CalendarView.selectionWasTapped`, set by `onDayTapped` and cleared by the
`onChange` that the selection triggers, so it describes exactly one change — the same one-pass
lifetime `previousSelection` has. It is folded into `selectionTravel`, which reports the distance
the disc *should* cover rather than the one it did: that keeps it out of `CalendarSelectionLayer`,
which already takes that single value and already exempts it from `==`. A separate input would
need the same exemption for the same reason, and is one more thing to get wrong.

Only the tap can be recognised, because only the tap happens in `CalendarView` — the card's paging
lives in `DayDetailsPagerView`, and `HomeView.setTodaySelected()` in a third place. Distinguishing
them at the action would mean giving `.setSelectedDayStamp` a provenance the reducer has no use
for. The consequence to know: the floating today button, pressed while the selection sits on
yesterday or tomorrow, still slides. It is a choice rather than a gesture and by this rule should
place, but it cannot say so from where it lives.

What the flight actually cost was the strobe. The disc is a mask, so every numeral it crosses
inverts to the page colour and back on the way past — a jump across the week flickered five digits
in sequence, and that, not the disc, was what was tiring. Speeding the sweep up only shortens each
flash; not crossing the intervening days removes them. A single step passes over nothing, which is
why it is the case that survives. The long throw once had a second, calmer curve of its own; it is
gone with the throws, having been tuned against a wobble a 50pt slide cannot produce. This is the
judgement `flightCapScreens` already makes about the calendar's own flight, and the one the row
identity already made about a change of row: motion that cannot be followed is not motion.

**A midnight rollover does not move the disc**, though it reads like a one-day step that should
slide. `.updateTodayDayStamp` writes `todayDayStamp` alone and never touches `selectedDayStamp`;
what moves is the today marker inside the grid, which is drawn per-cell and has no animation.

**The blurred copy draws the disc but does not animate it** (`animatesSelection`). A blur is
recomputed whenever what it covers changes, so a disc travelling inside `blurredBandLayer` costs a
gaussian per frame — the single cost the whole band is budgeted against — for a disc that is almost
never under the band and unreadable through it when it is. It is also the one input the two copies
are *meant* to disagree on, and that is safe only because it is constant per copy: each still
compares equal to its own previous self, which is all the identical-inputs rule protects.

`selectionTravel` is the one input deliberately **outside** the layer's `==`: it decides how a
change animates, never what is drawn, so the update that arrives once a selection has settled —
carrying nothing but the travel falling back to zero — must compare equal and skip the body. Include
it and every day chosen costs two rebuilds instead of one. `reduceMotion` is the opposite case and is
in the comparison; like the accent theme it is read in `CalendarView` and handed down, because a
body the layer decides to skip would never see an environment change of its own. Whether a day is
today needs no input of its own: it rides along inside `viewport`.

The disc is a ⌀28 view with `.position` applied from outside it, rather than a grid-sized layer
drawing a circle somewhere inside itself. That is what lets the inverted numerals be masked by the
disc itself, and it is why they are laid out relative to the disc's own centre rather than in grid
coordinates.

Nothing here reads the scroll. Every position in the grid and in the disc's layer is in content
space — the anchor moves the cull, not the coordinates — so a viewport re-anchor mid-glide cannot
break the interpolation, and a rebuild that simply dropped the disc's month removes it without a
transition rather than animating it away.

`CalendarState.dayDisplayStates` is **sparse**: it is recomputed by `computeDayDisplayStates`
(`Core/Redux/Reducers/DayDisplayStateComputer.swift`) in the reducer whenever cycle/tag/comment/range
state changes, and only days with content get an entry. A missing key means `DayDisplayState.empty` —
readers must treat absence as "nothing to show", never assume every day in `loadedRange` has an entry.

**The map is compared by its version, not by its contents.** `dayDisplayStatesVersion` is bumped by
the reducer, in the one place that writes the map and only when the recomputed map differs — so equal
versions mean an identical map, and `CalendarGridView.==` asks the integer instead of walking several
hundred keys twice on every frame of a scroll. Both are written together and nowhere else; write the
dictionary from anywhere else and the grid will keep drawing the old one. Most recomputes change
nothing drawable (a comment saved outside the loaded range, a tag renamed), which is why the compare
happens once in the reducer rather than in every reader.

`CalendarState.loadedRange` is centered on the viewport: `CalendarView` dispatches
`.calendarScrolledTo(center:)` as the user scrolls, and `DatabaseMiddleware` re-centers the range
(and its comment/tag observations) when the center gets close to an edge. Buffer and threshold live
in `Constants.Calendar` — do not hardcode them.

**The middleware decides against its own `observedRange`, not against the state it was handed.**
The state's `loadedRange` lags, and the serial effect queue did not fix that: `.setLoadedRange` is
a value `handle` *returns*, so it cannot reach the reducer while the burst of `.calendarScrolledTo`
that produced it is still queued ahead of it — and the calendar reports a new centre every
`centerReportStep` days, so a fling produces several. All of them carry the old range, and reading
the range from state made every one of them restart both observations — a burst
of GRDB starts per fling, which is what turned a latent data race into a reproducible crash.
`DatabaseMiddleware.observedRange` is written the moment the observations start, so the burst
collapses to one restart. It duplicates state deliberately; keep the two writes together. **The loaded range must stay wider than what the
calendar draws around the center** (a rendered viewport reaches about two months either way, per
`viewportBufferRatio`): a day scrolled into view before its range is loaded has no `DayDisplayState`,
so its bars, dots and comments visibly draw themselves in a moment later.

**Where the calendar sits is arithmetic, and it lives outside the view.** `CalendarLayout` takes the
screen height, the band's height and a week's height, and answers the six questions that used to be
computed properties scattered down `CalendarView`: what a week is sized against, where today rests,
how tall the day card may grow, how far the selected week shifts for an open card, what the scroll
offset should be, and which way the floating button points. The two positions that genuinely cost
something — `todayWeekCenterY` and `selectionOffset`, each a walk through the calculator's months —
stay as `@State`; everything derived from them is recomputed, because it is subtraction.

The day↔position conversions moved the other way, onto `MonthCalculator` itself (`weekCenterY(for:)`,
`originShift(from:)`, `monthCenterDaystamp(atContentY:)`), since every Y in this app is measured from
the top of the month holding *that calculator's* `currentDate`. Asking the calculator removes a
disagreement the old signatures allowed: `weekCenterY` took a calculator as an argument and read the
reference date off the view, and the two differ for exactly one pass — the midnight rollover that
replaces the calculator.

Neither type is a refactor for tidiness. These are the numbers that go subtly wrong (which height a
week is measured against, whether the band counts, what "today is off screen" means), and eight
lines of arithmetic in a row can be checked against the rules above in a way that the same eight
lines spread over eight hundred cannot.

**Scrolling must not rebuild day cells.** The grid (`CalendarGridView`) is `Equatable` and is drawn
for a fixed *anchor* offset; a scroll frame only slides that layer with `.offset`, and
`CalendarView.rebuildViewport` re-anchors it once the scroll has travelled
`CalendarConstants.viewportUpdateThreshold`. Everything the grid needs must therefore be a plain
value input — no store reads inside it — and the off-screen cull uses `anchorOffset`, never the live
scroll offset. The cull's buffer (`dayVisibilityBufferRatio`) is what covers the drift between two
anchors, so the two constants move together: it has to clear `viewportUpdateThreshold` plus one frame
of a fast fling, and it is a share of every cell drawn in both copies of the grid, so it is sized off
that arithmetic and not raised for comfort. `viewportBufferRatio` — the month walk that feeds the
cull — only has to stay wider than it. Month titles are culled on the same terms the days are. Per-day
calendar work (daystamp, day number) belongs in `MonthCalculator.getMonthCells(for:)`, which caches it
per month; never recompute it per frame.

**The scroll rail is measured once per calculator.** `getScrollLimits()` is the content-space position
of `minMonthOffset` and `maxMonthOffset`, so reaching it measures every month in between — two
`Calendar` calls each — and `scrollViewDidScroll` asks for it on every frame. It is cached on the
calculator and dropped only when the locale or first weekday changes. The month range is what keeps
that one walk affordable: at the ±200 years it once was, the first frame of the first drag paid for
~9600 `Calendar` calls. Do not widen it without measuring, and do not reach past the cache.

**A flight is capped, because a flight is only a flight while someone can follow it.**
`spring(forDistance:)` gives every distance the same fixed duration, which is right for a screen or
two and absurd from the rail: sixty years in 0.75s is thirteen screens per frame — a strobe, and
also the whole of the stutter, since every reported frame re-anchors the viewport, rebuilds the grid
and pushes a scroll centre that re-centres the loaded range and restarts the database observations
with it. `InfiniteScrollContainer.launchOffset` closes everything past
`CalendarConstants.flightCapScreens` instantly first, on the side the calendar is coming from, and
animates only the rest. Two screens is chosen against the 1400pt threshold in `spring(forDistance:)`
— it is the first cap that lands on the harder-damped curve — so changing it silently changes how
the calendar settles. A day selection re-centring never reaches the cap, because only a day already
on screen can be tapped.

The cap only shrinks a second problem it does not fix on its own: the raw analytic solution is not
1 at `t = 1` for most `damping`/`initialVelocity` pairs — at ζ=0.95 it crosses its target at
`t = 0.904` and is still mid-overshoot when the window ends, off by 0.00705% of the distance. Before
the fix, `progress` snapped that residual to 1 instead of arriving there, so the cap could only
shrink the visible jump (19pt down to a tenth of a point on the rail), not remove it.
`SpringInterpolation.progress` now divides the raw solution by that same raw solution evaluated at
`t = 1` (`rawValue`), so the curve is rescaled to actually land on 1 at the boundary instead of
being cut off near it — the jump this section used to describe is gone by construction, not by
truncation.

**A flight is stopped in `dismantleUIView`, and it cannot be stopped in `deinit`.** A
`CADisplayLink` retains its target and the main run loop retains the link until `invalidate()`, so
an animating `Coordinator` is held by an object that outlives the app — its `deinit` is only ever
entered once the link is already gone, which makes stopping there a no-op in exactly the state it
was written for. That was never a crash, because `animatingScrollView` is weak and the tick after
SwiftUI drops the scroll view ends the animation itself; what it cost was up to 0.75s of frames
writing `contentOffset` on a detached scroll view, each reporting a scroll centre that reaches
`DatabaseMiddleware` and re-centres the loaded range for a calendar that no longer exists.
`Coordinator.cleanUp()` also clears `pendingReport`, which is the same effect one run loop turn
wide: the report is delivered whatever happens to the view in between, and the queued block reads
the value back so clearing it is enough. New teardown work belongs in `cleanUp()` for both reasons —
`deinit` cannot be relied on to run at teardown, and it may not run on the main thread, where an
`invalidate()` on a link added to `.main` wants to be.

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

**All access is `async`.** `DatabaseServiceProtocol` is `async throws` throughout, backed by GRDB's
async `read`/`write`, so a caller on the main actor waits for a transaction without blocking a
thread on it. Ordering survives the change: requests reach the GRDB queue in the order callers
reached their `await`, and each write is still one transaction.

**Observations** return `AnyDatabaseCancellable` — the caller must retain the token to keep the
observation alive. They are main-actor-bound at both ends: started from the main actor and
delivering there, via `ValueObservation.start`'s `@MainActor` overload (default `.mainActor`
scheduler — the same `DispatchQueue.main` delivery as before, but now checked by the compiler
rather than assumed). That is not a convenience for the UI. The token is shared mutable state whose
`deinit` cancels the observation, so whoever holds it has to be isolated somewhere, and the main
actor is where the values were always going.

**Migrations** are in `DatabaseService.runMigrations(_:)`. Always append new migrations — never modify existing ones.

### Environments

**Concurrency checking:** `SWIFT_STRICT_CONCURRENCY = complete` and `SWIFT_VERSION = 6.0` on all
four configurations. The `complete` tree reached zero warnings under Swift 5 mode first, verified
by archive; `SWIFT_VERSION` moved to `6.0` on that basis, turning the same diagnostics into errors.
A new concurrency error means new code — there is no warning tier left to catch it first.

**The build gate is one ordinary build.** A simulator build compiles every file an archive does, so
archiving is for releases, not for checking a change. Running the app is worth the trouble only when
something specific needs looking at — a layout or an animation, or a change to how services are
registered, which is the one case where a green build means nothing (see the `ServiceLocator` note
below). Everything else is read from the code.

**The first attempt at `SWIFT_VERSION = 6.0` was reverted, and the reason had nothing to do with
concurrency.** Language mode changes how Swift infers a generic parameter from an existential
argument. `ServiceLocator.addService` used to be `addService<T>(service:)`, called as
`addService(service: keychain)` where `keychain` is `let keychain: KeychainServiceProtocol =
KeychainService()`. Under Swift 5, `T` bound to the annotation, `KeychainServiceProtocol` — under
Swift 6, the compiler opened the existential and bound `T` to the concrete `KeychainService`
instead. Registration and `@Injected`'s lookup keyed on different types after that, and every
resolution of that service was the `ServiceLocator.swift` fatalError, on first launch, before any
UI. `complete` under Swift 5 mode produces the same set of *diagnostics* Swift 6 mode does, which
is what made the first attempt look safe from an archive alone — archive only compiles, and this
bug didn't fail to compile, it failed to run. Confirmed by actually launching the app in the
simulator: 5.0 resolved `T=KeychainServiceProtocol` and worked, 6.0 resolved `T=KeychainService`
and crashed on `.checkAuthState`, both from an otherwise identical tree.

The fix, now in place, is that `addService` takes the type it keys on as an explicit `T.Type`
argument (`addService(KeychainServiceProtocol.self, service: keychain)`) instead of inferring `T`
from `service`'s declared type — see the Dependency Injection section above and the doc comment on
`ServiceLocator`. That removes the inference this depended on entirely, rather than relying on a
language mode not to open the existential. Re-verified the same way: launched in the simulator
under `SWIFT_VERSION = 6.0`, `checkAuthState` resolves `KeychainServiceProtocol` correctly and the
welcome screen renders. **Any future change to `ServiceLocator` or to how a service is registered
needs the same verification an archive cannot give — launch the app, don't just compile it.**

**Do not turn on `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` to make a warning go away.** That was
tried while getting here, and it is what produced 18 `nonisolated` extensions in `Core/Models/`
that got the whole migration reverted once; this app's value layer is deliberately reachable from
off-main. Every warning `complete` found had a narrower fix:

- **Service protocols are `Sendable`.** `APIServiceProtocol`, `PushPermissionServiceProtocol`,
  `KeychainServiceProtocol`, `AnalyticsServiceProtocol` and `AppearanceServiceProtocol` all refine
  `Sendable` now, and their concrete types conform alongside — each is either a `final class` with
  no mutable stored state or one guarded the ways below. `DatabaseServiceProtocol` already was.
  `TapticFeedbackServiceProtocol` doesn't need to be: it is `@MainActor` outright (see
  `TapticFeedbackService.swift`), which is a stronger guarantee for a type only ever called from
  `Middleware`. This is what let `@Injected var apiService: APIServiceProtocol` inside a `Task {
  }` in `AuthMiddleware` stop being a warning: an existential of a non-Sendable protocol can't
  cross into a `@Sendable` closure, Sendable or not the closure only ever runs where it was made.
- **A system type that isn't Sendable-audited gets `@preconcurrency import`, file-scoped.**
  `KeychainService.swift` (`Security`, for `CFString`/`CFBoolean` keychain query values) and
  `PushPermissionService.swift` (`UserNotifications`, for `UNUserNotificationCenter`) do this. It
  only silences the specific module named, in the one file that imports it that way — it is not a
  blanket escape hatch.
- **A value the compiler can't see is locked gets `nonisolated(unsafe)`, next to the lock that
  actually protects it.** `Daystamp`'s `ReferenceDate` cache and `DayDetailsView`'s
  `DayTitleFormatters` cache both already took an `NSLock` before every read and write; the
  annotation just tells the type system what was already true. `AppearanceService.defaults`
  (`UserDefaults`) is the same annotation for a different reason — no lock, because Apple's own
  documented thread-safety is the guarantee there, not ours.
- **A `PreferenceKey.defaultValue` is a computed property, never a stored one.** `static var
  defaultValue: T = x` is stored global mutable state by the same rule as any other `static var`;
  `static var defaultValue: T { x }` has no backing storage and the warning has nothing to attach
  to. `FlowLayoutHeightKey`, `FlowPickerHeightKey`, `DayCardNaturalHeightKey`, `DayCardFrameKey`
  and `TodayVisibilityPreferenceKey` are all written this way now — match it for new keys.
- **A `View`'s custom `Equatable` conformance that reads its own stored properties is isolated to
  `@MainActor` on the conformance, not the whole type.** `CalendarGridView` and
  `CalendarSelectionLayer` infer `@MainActor` on their stored properties from being a `View`
  (`body` is a `@MainActor` requirement), same as any SwiftUI view; `==` is a nonisolated
  `Equatable` requirement by default, and reading those properties from it is what crossed. Both
  now read `View, @MainActor Equatable` — SE-0470's per-conformance isolation, not a redesign.
- **A shared mutable cursor threaded through a closure-based algorithm is a `final class`, marked
  `@unchecked Sendable` with a comment saying why.** `FlowLayout`'s `alignmentGuide`-based
  wrapping needs one running offset visible across every child's guide closures — a captured `var`
  can't do that, only a reference type can — and `FlowLayoutCursor` says in comment why treating
  it as safe is correct rather than convenient: SwiftUI resolves one stack's guides serially, in
  `ForEach`'s order, which is what the offset accumulation already depended on.
- **A method only `deinit` needs to call off the main actor is `nonisolated`, deliberately,
  alongside the specific properties it touches.** `InfiniteScrollContainer.Coordinator.
  stopAnimation()` inferred `@MainActor` from conforming to `UIScrollViewDelegate`, like every
  other method there — correctly, since every *other* caller is already on the main actor. `deinit`
  is the one caller that Swift will never let be, isolated class or not (see "A flight is stopped
  in `dismantleUIView`" above), so `stopAnimation()` and the two properties it touches
  (`displayLink`, `animatingScrollView`) are `nonisolated` / `nonisolated(unsafe)` explicitly,
  rather than the whole class losing the inferred isolation everything else there correctly relies on.

There are **two** app schemes, both shared, and they select a configuration per *action* — the
scheme name alone does not tell you which API a build talks to:

| Scheme | Run / Test / Analyze | Profile | Archive |
|---|---|---|---|
| RedCalendar-Production | Debug | Release | Release |
| RedCalendar-Staging | Debug-Staging (Run) · Debug (Test, Analyze) | Release | Release-Staging |

The four configurations map to two API hosts, via `API_BASE_URL` on the **target's** build settings
(the project level also sets it, but the target's value is what reaches `Info.plist`):

| Config | API host |
|---|---|
| Debug | `https://api.calendar.red` (production) |
| Release | `https://api.calendar.red` (production) |
| Debug-Staging | `https://staging.calendar.red` |
| Release-Staging | `https://staging.calendar.red` |

**There is no dev API.** Debug and Release both point at production — a plain Run of
`RedCalendar-Production` writes to live data. Two consequences of the per-action mapping that are
easy to trip over: `RedCalendar-Staging`'s Test and Analyze actions build **Debug**, so unit tests
under the staging scheme hit production, and its Profile action builds **Release**, so an Instruments
run of the staging scheme is a production build. Only Run and Archive are actually staging there.

Every scheme other than these two (`AppMetrica-Package`, `KSCrash-Package`, `BootTimeMonitor`,
`Filters`, `Installations`, `Recording`, `Reporting`, `Sinks`) belongs to an SPM dependency — never
build the app through one.

Building from the command line means naming the configuration explicitly, since `xcodebuild`
defaults to `Release` when `-scheme` is omitted:

```
xcodebuild -project RedCalendar-Female.xcodeproj -scheme RedCalendar-Staging \
  -configuration Debug-Staging -destination 'platform=iOS Simulator,name=iPhone 16' build
```

`#if DEBUG` maps to both Debug and Debug-Staging (`SWIFT_ACTIVE_COMPILATION_CONDITIONS` at the
project level) — use it for `isDevelopment` flags (e.g., APNs sandbox). Note that it does **not**
line up with which API is in use: Debug is a production build with `DEBUG` defined.

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

## Status

`SYNC.md` §12 is the source of truth for what has shipped and what hasn't — check it there rather
than here before starting sync/storage work. As of this writing: CRUD for cycle data, the
tags/symptoms system, offline sync, the `api.calendar.red` endpoint, day tap interactions, and
account deletion (§17) and email binding/change (§18) are all shipped, server and client.

Open work is server-only, in `redcalendar-api` (SYNC.md §12, items 14–16): bulk phone→UID
migration, moving `check-phone` to a local lookup, and retiring Firebase. Notification scheduling
(§15) is out of scope and undesigned — only the DB groundwork (`user_devices.timezone`,
`last_seen_at`) is in place; no iOS code references `TimeZone` yet.
