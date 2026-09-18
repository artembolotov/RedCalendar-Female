# RedCalendar Female

iOS app for menstrual cycle tracking. SwiftUI + a hand-rolled Redux architecture, GRDB for local
storage, and offline-first sync against `api.calendar.red`.

**Requirements:** iOS 15.4+, Xcode 26.4+, Swift 5.9+.

## Architecture

### Redux

- `AppStore` is a concrete `@MainActor final class` — not a generic `Store<State, Action>` (a
  generic version once shipped and broke every archive build; see `CLAUDE.md` for the history).
- `AppAction` is grouped by domain (`.auth`, `.calendar`, `.data`, `.sync`, `.push`, `.analytics`,
  `.appearance`, `.devices`), each wrapping its own sub-enum. A middleware that owns a domain
  switches over it exhaustively, so a new action case that nothing handles is a build error.
- Reducers are pure; all async work and API calls live in middleware, dispatched through a single
  serial effect queue.
- Dependency injection goes through `ServiceLocator.shared` / `@Injected`, keyed by protocol type.

### Key types

- **`Daystamp`** — the app's date type for calendar days (`Int` days since 2001-01-01), used
  everywhere a "day" is the concept instead of `Date`.
- **`ResolvedCycleSettings`** / **`CycleForecast`** — cycle length, period length and luteal phase
  are measured back off recorded cycles (median over a rolling window) rather than left as raw,
  unvalidated server data.
- **`CycleRecord+Queries`** — the single place that answers "which cycle owns this day," "can a
  period be started/ended here," etc. Never re-implemented inline.

See `CLAUDE.md` for the full set of architectural rules (state shape, sync, notifications,
calendar rendering, localization, concurrency) — it is the canonical reference for this codebase.
`SYNC.md` covers the offline sync protocol and server contract in detail.

## Project structure

```
App/          — entry point, AppDelegate, Configurator (DI setup)
Core/
  Constants.swift
  DI/         — ServiceLocator, @Injected
  Models/     — Daystamp, cycle/comment/tag GRDB records, sync payloads, resolved settings, …
  Redux/
    Actions/    — AppAction and its per-domain sub-actions
    Middleware/ — AuthMiddleware, DevicesMiddleware, MigrationMiddleware, DatabaseMiddleware,
                   SyncMiddleware, PushNotificationsMiddleware, AnalyticsMiddleware,
                   AppearanceMiddleware, FeedbackMiddleware, LoggerMiddleware
    Reducers/   — AppReducer, DayDisplayStateComputer
    States/     — AppState, AuthState, CalendarState, SyncState, EmailAuthState, PhoneAuthState,
                   NotificationState, DevicesState
    AppMiddleware.swift, AppStore.swift
  Services/   — APIService, KeychainService, AnalyticsService, PushPermissionService,
                 TapticFeedbackService, AppearanceService, DatabaseService (GRDB)
  Utils/      — AppLogger, DeviceModel
Common/
  Components/, Extensions/, Modifiers/, Views/  — shared UI building blocks
Features/
  Auth/       — Welcome/Login, email and phone (flash call) sign-in
  Home/       — infinite-scroll calendar, day details card, comments/tags/flow/ovulation editors
  Settings/   — cycle settings, device list, notifications
  Statistics/ — cycle statistics
```

Feature folders own their own views and feature-specific models; shared types live in
`Core/Models/`.

## Tech stack

- **SwiftUI** for all UI (no `NavigationView`/UIKit except a few isolated wrappers).
- **GRDB** 7.x — local SQLite storage, fully `async`, all access through `DatabaseServiceProtocol`.
- **AppMetrica** 5.11.1 — analytics and crash reporting.
- **PhoneNumberKit** 4.1.1 — phone number formatting/validation for flash-call sign-in.

## Environments

Two shared schemes, each mapping differently per build action:

| Scheme | Run / Test / Analyze | Profile | Archive |
|---|---|---|---|
| RedCalendar-Production | Debug | Release | Release |
| RedCalendar-Staging | Debug-Staging (Run) · Debug (Test, Analyze) | Release | Release-Staging |

| Config | API host |
|---|---|
| Debug | `https://api.calendar.red` (production) |
| Release | `https://api.calendar.red` (production) |
| Debug-Staging | `https://staging.calendar.red` |
| Release-Staging | `https://staging.calendar.red` |

There is no separate dev API — a plain Debug run talks to production. `API_BASE_URL` is set per
build configuration on the target and read via `Constants.URLs.api`.

Command-line build example:

```
xcodebuild -project RedCalendar-Female.xcodeproj -scheme RedCalendar-Staging \
  -configuration Debug-Staging -destination 'platform=iOS Simulator,name=iPhone 16' build
```

CI (`.github/workflows/build-ios.yml`) archives `RedCalendar-Production` on every push to `main`
and uploads to TestFlight.

## Testing

Unit tests live in `RedCalendar-FemaleTests` and cover cycle forecasting, ovulation logic, cycle
day context, resolved cycle settings, notification preference resolution, sync profile push
payloads, JSON merge logic, and the localization string catalog's own structural rules
(`StringCatalogTests`).

## Status

Shipped, client and server: cycle CRUD, tags/symptoms, offline sync, the `api.calendar.red`
endpoint, day-tap interactions, account deletion, email binding/change, and the device list.

Open work is server-only (bulk phone→UID migration, moving `check-phone` to a local lookup,
retiring Firebase). Notification *scheduling* is undesigned; only the account-level mute
preference and its sync path have shipped on the client so far.

See `SYNC.md` §12 for the authoritative, up-to-date breakdown.

## License

Source is available to view for transparency and to enable free GitHub Actions CI builds. Use,
copying, modification, or distribution requires written permission from the author. See
[LICENSE](LICENSE).

---

**Author:** Artem Bolotov
