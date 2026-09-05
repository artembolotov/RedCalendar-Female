//
//  DataWriteOperation.swift
//  RedCalendar-Female
//

import SwiftUI

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
    case cycleSettings
    case notificationSettings
    case profileName

    /// What the user is told. Names the thing that did not get saved, because the day card is
    /// still showing it — for a comment, the reducer has already put the new text on screen
    /// (see `appReducer`'s `.saveComment`), so "не сохранилось" is the only way they would know.
    /// Scoped `WriteError` rather than after this type: the enum names an operation, the strings
    /// name a failure, and the alert they end up in is the one the user reads. `logLabel` below
    /// keeps the operation's own name, which is what a log is looking for.
    var failureMessage: LocalizedStringKey {
        switch self {
        case .periodStart: return "WriteError.PeriodStart"
        case .periodEnd:   return "WriteError.PeriodEnd"
        case .flowLevel:   return "WriteError.FlowLevel"
        case .comment:     return "WriteError.Comment"
        case .dayTags:     return "WriteError.DayTags"
        case .userTag:     return "WriteError.UserTag"
        case .cycleSettings: return "WriteError.CycleSettings"
        case .notificationSettings: return "WriteError.NotificationSettings"
        case .profileName: return "WriteError.ProfileName"
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
        case .cycleSettings: return "cycleSettings"
        case .notificationSettings: return "notificationSettings"
        case .profileName: return "profileName"
        }
    }
}
