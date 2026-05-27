//
//  DatabaseMiddleware.swift
//  RedCalendar-Female
//

import Foundation
import GRDB

// MARK: - DatabaseMiddleware

final class DatabaseMiddleware {
    @Injected private var dbService: DatabaseServiceProtocol

    private var cyclesToken: AnyDatabaseCancellable?
    private var userTagsToken: AnyDatabaseCancellable?
    private var commentsToken: AnyDatabaseCancellable?
    private var dayTagsToken: AnyDatabaseCancellable?

    private var currentLoadedRange: ClosedRange<Daystamp>?

    // MARK: - Handle

    func handle(state: AppState, action: AppAction, dispatch: @escaping (AppAction) -> Void) async -> [AppAction] {
        switch action {
        case .setAuthState(let authState):
            if case .authenticated = authState {
                startPermanentObservations(dispatch: dispatch)
                let initialRange = state.calendarState.loadedRange
                startRangeObservations(for: initialRange, dispatch: dispatch)
                currentLoadedRange = initialRange
            } else if case .notAuthenticated = authState {
                cancelAll()
            }

        case .calendarScrolledTo(let center):
            let buffer = 180
            let newRange = (center - buffer)...(center + buffer)
            guard let loaded = currentLoadedRange else { break }
            let needsExpansion = center.rawValue - loaded.lowerBound.rawValue < 30
                              || loaded.upperBound.rawValue - center.rawValue < 30
            if needsExpansion {
                currentLoadedRange = newRange
                startRangeObservations(for: newRange, dispatch: dispatch)
                return [.setLoadedRange(newRange)]
            }

        default:
            break
        }
        return []
    }

    // MARK: - Private Methods

    private func startPermanentObservations(dispatch: @escaping (AppAction) -> Void) {
        cyclesToken = dbService.observeCycles { records in
            dispatch(.setCycles(records))
        }
        userTagsToken = dbService.observeUserTags { records in
            dispatch(.setUserTags(records))
        }
    }

    private func startRangeObservations(for range: ClosedRange<Daystamp>, dispatch: @escaping (AppAction) -> Void) {
        let intRange = range.lowerBound.rawValue...range.upperBound.rawValue

        commentsToken = dbService.observeComments(in: intRange) { records in
            let dict = Dictionary(uniqueKeysWithValues: records.map {
                (Daystamp(rawValue: $0.dayNumber), $0)
            })
            dispatch(.setVisibleComments(dict))
        }

        dayTagsToken = dbService.observeDayTags(in: intRange) { records in
            let dict = Dictionary(uniqueKeysWithValues: records.map {
                (Daystamp(rawValue: $0.dayNumber), $0.tagIds)
            })
            dispatch(.setVisibleDayTags(dict))
        }
    }

    private func cancelAll() {
        cyclesToken = nil
        userTagsToken = nil
        commentsToken = nil
        dayTagsToken = nil
        currentLoadedRange = nil
    }
}
