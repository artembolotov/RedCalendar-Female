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
    case push(PushAction)
    case analytics(AnalyticsAction)
    case appearance(AppearanceAction)

    /// Deliberately outside every group: it is dispatched when the app becomes active and asks
    /// whoever has unfinished work to try again. Today that is only the APNs token; the sync
    /// this app does not have yet is the other obvious claimant, which is exactly why it does not
    /// belong to `push`.
    case retryFailedTasks
}

enum AuthAction: Sendable {
    case check
    case set(AuthState)
    case logout
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
    /// The `user_profile` row, or `nil` while the table is empty — today that's always, since
    /// only a sync run (SYNC.md §12 item 8) ever writes it (§3.1).
    case setUserProfile(UserDetails?)

    // Day editing
    case markPeriodStart(Daystamp)
    case markPeriodEnd(Daystamp)
    case unmarkPeriodEnd(Daystamp)
    case setFlowLevel(Daystamp, Int?)
    case saveComment(Daystamp, String)
    case setDayTags(Daystamp, [String])

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
