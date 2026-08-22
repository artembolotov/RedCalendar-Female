//
//  DataWriteOperation.swift
//  RedCalendar-Female
//

/// What the user was trying to record when a database write failed.
///
/// The state tree carries *this* rather than the error that caused it, for the same reason every
/// other error in `AppState` is a concrete type: it has to be `Equatable` and `Sendable`, and the
/// UI has to be able to say something useful without rendering a `localizedDescription` at
/// someone. The underlying error is logged where it happens and goes no further.
enum DataWriteOperation: Sendable, Equatable {
    case periodStart
    case periodEnd
    case flowLevel
    case comment
    case dayTags
    case userTag

    /// What the user is told. Names the thing that did not get saved, because the day card is
    /// still showing it — for a comment, the reducer has already put the new text on screen
    /// (see `appReducer`'s `.saveComment`), so "не сохранилось" is the only way they would know.
    var failureMessage: String {
        switch self {
        case .periodStart: return "Отметка начала месячных не сохранилась. Попробуйте ещё раз."
        case .periodEnd:   return "Отметка окончания месячных не сохранилась. Попробуйте ещё раз."
        case .flowLevel:   return "Интенсивность не сохранилась. Попробуйте ещё раз."
        case .comment:     return "Заметка не сохранилась. Попробуйте ещё раз."
        case .dayTags:     return "Симптомы не сохранились. Попробуйте ещё раз."
        case .userTag:     return "Тег не сохранился. Попробуйте ещё раз."
        }
    }

    var logLabel: String {
        switch self {
        case .periodStart: return "markPeriodStart"
        case .periodEnd:   return "markPeriodEnd"
        case .flowLevel:   return "setFlowLevel"
        case .comment:     return "saveComment"
        case .dayTags:     return "setDayTags"
        case .userTag:     return "userTag"
        }
    }
}
