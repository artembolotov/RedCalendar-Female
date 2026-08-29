//
//  AppAction.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

/// Grouped by domain rather than flat, and the grouping buys one thing: a middleware that owns a
/// domain can switch over that domain **exhaustively**.
///
/// Flat, every middleware ended in `default: break`, so a new case compiled everywhere and was
/// handled nowhere — the compiler had nothing to say about a `.markPeriodEnd` that no middleware
/// wrote to the database. Now `DatabaseMiddleware` switches `DataAction` with no `default`,
/// `AuthMiddleware` switches `AuthAction` with no `default`, and adding a case to either is a
/// build error in the file that would have had to handle it.
///
/// The outer switch still takes a `default`, and has to: every middleware sees every action.
/// What each one *owns* is the inner switch, and that is where the exhaustiveness is worth
/// having. A middleware that merely observes another domain — `PushNotificationsMiddleware`
/// watching for authentication, `FeedbackMiddleware` watching for almost everything — matches the
/// cases it cares about and takes a `default`, because a new auth action genuinely is none of its
/// business.
enum AppAction: Sendable {
    case auth(AuthAction)
    case calendar(CalendarAction)
    case data(DataAction)
    case sync(SyncAction)
    case push(PushAction)
    case analytics(AnalyticsAction)
    case appearance(AppearanceAction)

    /// Deliberately outside every group: it is dispatched when the app becomes active and asks
    /// whoever has unfinished work to try again. Two claimants now — the APNs token and a sync
    /// run — which is exactly why it belongs to neither `push` nor `sync`.
    case retryFailedTasks
}

enum AuthAction: Sendable {
    case check
    case set(AuthState)
    case logout
    /// Clears `AuthState.authenticated`'s `isFreshRegistration` once `CycleOnboardingView` is
    /// done. Deliberately not another `.set(.authenticated(...))`: that pattern is also what
    /// `SyncMiddleware` reads as "the user just signed in" (an undebounced sync run),
    /// `AuthMiddleware` itself as a fresh session (a repeat push-permission request), and
    /// `DatabaseMiddleware` as a reason to (re-)start its observations. Re-dispatching it here
    /// would fire all three for an event none of them mean.
    case completedRegistrationOnboarding
}

enum CalendarAction: Sendable {
    case updateToday
    case selectDay(Daystamp?)
    /// The viewport's centre, reported as the user scrolls, so the loaded range can follow it.
    case scrolledTo(center: Daystamp)
}

/// The day data: what the database says, and what the user asks it to become.
///
/// Both halves are one domain because `DatabaseMiddleware` owns both of them — the reads are the
/// observations it starts, the writes are the transactions it runs. Splitting them would give it
/// two exhaustive switches over halves that only make sense together.
enum DataAction: Sendable {
    // Database → store
    case setCycles([CycleRecord])
    case setUserTags([UserTagRecord])
    case setVisibleComments([Daystamp: String])
    case setVisibleDayTags([Daystamp: [String]])
    case setFlowLevels([Daystamp: Int])
    case setLoadedRange(ClosedRange<Daystamp>)
    /// The `user_profile` row, or `nil` while the table has none — and also while the row it has
    /// carries no `user_id`, which `UserDetails` requires (§5.1 step 7 is what fills it).
    case setUserProfile(UserDetails?)
    /// The cycle half of the same row, dispatched beside it and read from the record directly.
    ///
    /// Separate because identity and settings have separate owners (§4.4) and separate lifetimes:
    /// the row can carry a cycle length the user just chose while the server has not yet named an
    /// owner for it — a settings edit made before the first successful run creates exactly that
    /// row. Folded into `.setUserProfile`, that edit would come back as `nil` and the number would
    /// visibly snap back to the fallback on screen.
    case setCycleSettings(UserSettings.CycleSettings?)

    // Day editing
    case markPeriodStart(Daystamp)
    case markPeriodEnd(Daystamp)
    case unmarkPeriodEnd(Daystamp)
    case setFlowLevel(Daystamp, Int?)
    case saveComment(Daystamp, String)
    case setDayTags(Daystamp, [String])

    // The cycle settings — the device's half of the profile (SYNC.md §4.4), and the first thing
    // in this app that produces a `changes.profile` at all.
    //
    // Two cases rather than one carrying the pair, because an edit writes the key it changed and
    // no other: the screen shows a fallback for a value the user has never chosen, and storing
    // that fallback would state a choice they did not make. Both carry a value already inside
    // `Constants.Cycle`'s bounds — the steppers cannot leave them — and the reducer clamps again
    // anyway, since the bound protects the prediction loop rather than the control.
    case setCycleLength(Int)
    case setPeriodLength(Int)

    // The catalogue the day's tags are chosen from
    /// Carried whole rather than as a name and a category: the reducer puts this exact record
    /// into `userTags` on the way past and the middleware writes this exact record to the disk,
    /// so there is one of it. It also keeps the reducer a pure function of its inputs — a
    /// reducer that minted the tag's id itself would not be.
    case createUserTag(UserTagRecord)
    /// Same shape as `createUserTag`, for the same reason: the edit form already holds the
    /// record it is changing, so it hands over the whole updated one rather than an id plus the
    /// fields that moved.
    case updateUserTag(UserTagRecord)
    /// The record with `name` already `nil` — this table's soft delete (see `UserTagRecord`) —
    /// built by the caller exactly as `updateUserTag`'s is, so the reducer and the middleware
    /// both just write what they are handed.
    case deleteUserTag(UserTagRecord)
    /// Dispatched by `TagsSheetView` the moment a long press opens a tag into its edit form.
    /// Nothing about the tag changes — this exists only so `FeedbackMiddleware` has something to
    /// react to. A `.contextMenu` gives its own activation haptic for free; the direct transition
    /// that replaced it does not, and this is what puts an equivalent one back on the gesture.
    case beganEditingUserTag

    // Write outcome
    case writeFailed(DataWriteOperation)
    case dismissWriteFailure
}

/// The sync run (SYNC.md §5), owned by `SyncMiddleware`.
///
/// Four cases and not one more, because most of a run is not expressible as an action: the
/// pushing, the pulling and the applying all happen inside one method that has to be callable
/// from outside the store too (§8 — the background push handler needs a return value, and `send`
/// has none). What is here is the run's edges — asking for one, saying what it is doing, and the
/// two brackets `DatabaseMiddleware` needs.
enum SyncAction: Sendable {
    /// Ask for a run. Every trigger in §5.6 lands here; the reason decides only whether it is
    /// debounced, and shows up in the log.
    case requested(SyncReason)
    case setState(SyncState)
    /// A run starting from cursor 0 — first install, post-wipe, a grown `known_tables`, or
    /// `full_resync_required` (§5.5). `DatabaseMiddleware` pauses its observations between these
    /// two, because applying a whole history row by row otherwise redraws the calendar once per
    /// transaction.
    ///
    /// The pause holds across every `has_more` page of the run, and the closing bracket is sent
    /// on **every** exit including failure and cancellation. Observations that never came back up
    /// are a calendar that stops updating until the app is restarted.
    case beganFullResync
    case finishedFullResync
}

/// Why a run was asked for (§5.6). `.localEdit` is the only one that waits — every other trigger
/// is already a moment the user stopped, or an event that will not repeat.
enum SyncReason: String, Sendable {
    case authenticated
    case localEdit
    case appActive
    case appBackground
    case remoteNotification
    case retry
    /// A run asking again because the last one ended with the import still running (§10.4).
    case importPoll

    var isDebounced: Bool { self == .localEdit }
}

enum PushAction: Sendable {
    case setAPNSToken(APNSToken)
    /// `nil` asks the middleware to go and read the real state from the system.
    case setPermissionState(PushPermissionState?)
}

enum AnalyticsAction: Sendable {
    case checkStatus
    case setActivated(Bool)
}

enum AppearanceAction: Sendable {
    case checkAccentTheme
    case setAccentTheme(AccentTheme)
}
