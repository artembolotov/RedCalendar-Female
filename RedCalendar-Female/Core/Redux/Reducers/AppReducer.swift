//
//  AppReducer.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import UIKit

func appReducer(state: AppState, action: AppAction) -> AppState {
    var state = state
    var recomputeDayDisplayStates = false

    switch action {

    case .auth(let authAction):
        switch authAction {

        case .check:
            break

        case .set(let authState):
            state.authState = authState
            if case .notAuthenticated = authState {
                state.notifications.apnsToken = nil
                state.calendarState = CalendarState()
            }

        case .logout:
            break
        }

    case .calendar(let calendarAction):
        switch calendarAction {

        case .updateToday:
            state.calendarState.todayDayStamp = Daystamp.today(calendar: .current)
            recomputeDayDisplayStates = true

        case .selectDay(let dayStamp):
            state.calendarState.selectedDayStamp = dayStamp

        case .scrolledTo:
            break
        }

    case .data(let dataAction):
        switch dataAction {

        case .setCycles(let cycles):
            // Sorted-by-startDay invariant: cycle queries and the display computer
            // rely on this order (see CycleRecord+Queries).
            state.calendarState.cycles = cycles.sorted { $0.startDay < $1.startDay }
            recomputeDayDisplayStates = true

        case .setUserTags(let tags):
            state.calendarState.userTags = tags
            recomputeDayDisplayStates = true

        case .setVisibleComments(let comments):
            state.calendarState.visibleComments = comments
            recomputeDayDisplayStates = true

        case .setVisibleDayTags(let dayTags):
            state.calendarState.visibleDayTags = dayTags
            recomputeDayDisplayStates = true

        case .setFlowLevels(let flowLevels):
            state.calendarState.flowLevels = flowLevels
            recomputeDayDisplayStates = true

        case .setLoadedRange(let range):
            state.calendarState.loadedRange = range
            recomputeDayDisplayStates = true

        // Cycle settings ride along with the profile, so display states have to be rebuilt
        // here too — otherwise settings changed on another device only take effect at the next
        // unrelated cycle/tag/comment change.
        case .setUserProfile(let profile):
            state.userProfile = profile
            recomputeDayDisplayStates = true

        // The write actions that also reduce, and it is a latency decision rather than a
        // difference in kind. Everything below them reaches the screen the long way round: the
        // middleware writes, GRDB's observation notices, and `.setVisibleComments` and friends
        // come back to the reducer a round trip later. That is invisible for a tap on a flow
        // level, whose sheet does not move — and it is not invisible for a comment or for a
        // day's tags, because the editing sheet is dismissing at the same moment and the day
        // card underneath is already on screen, showing the old value, waiting for the trip to
        // finish.
        //
        // Reducing here puts the new value on screen in the frame `send` returns in (see
        // `AppStore.send`), and the write still goes to the database exactly as it did. The trip
        // still happens; when it lands, `.setVisibleComments` / `.setVisibleDayTags` carries the
        // value already sitting here, so `if newState != state` swallows it and nothing redraws
        // twice.
        //
        // The cost is that state leads the disk instead of mirroring it, and that is what
        // `.writeFailed` below is for: an edit that fails to save is on screen as though it
        // saved, so the middleware both tells the user and re-reads the range to put the stored
        // value back.
        case .saveComment(let dayStamp, let text):
            // Absence, not an empty string: `visibleComments` is sparse, and the middleware
            // stores the same emptiness as a `nil` comment — this table's soft delete.
            if text.isEmpty {
                state.calendarState.visibleComments.removeValue(forKey: dayStamp)
            } else {
                state.calendarState.visibleComments[dayStamp] = text
            }
            recomputeDayDisplayStates = true

        case .setDayTags(let dayStamp, let tagIds):
            // Written exactly as the observation will write it, the empty array included:
            // `day_tags` has no soft delete, so a day cleared of every tag keeps its row and
            // comes back as an empty list rather than as an absent key. Storing absence here
            // instead would make the round trip land a *different* value and redraw a second
            // time.
            state.calendarState.visibleDayTags[dayStamp] = tagIds
            recomputeDayDisplayStates = true

        // Reduces for the same reason the two above do, one screen further in: the picker is
        // on screen while the creation sheet dismisses, so a tag that arrived a round trip
        // later would appear after the sheet had already gone — and on an empty catalogue the
        // whole screen changes with it, from the explanation to the picker.
        //
        // Appended rather than sorted in: nothing reads `userTags` in order — the sheet groups
        // and sorts them for itself — and appending is where the unordered fetch puts the new
        // row too, so the round trip lands the same array and redraws nothing.
        case .createUserTag(let tag):
            state.calendarState.userTags.append(tag)
            recomputeDayDisplayStates = true

        // Both replace the existing row in place with the record the caller already built —
        // for a delete that record carries `name == nil`, which is exactly what the soft-deleted
        // row looks like once the observation reads it back, and exactly what every reader of
        // `userTags` already filters out (see `TagsSheetView.availableTags`). Reducing here
        // rather than waiting on the round trip is the same latency decision as `createUserTag`:
        // the edit form and the confirmation dialog are both dismissing at this moment.
        case .updateUserTag(let tag), .deleteUserTag(let tag):
            if let index = state.calendarState.userTags.firstIndex(where: { $0.id == tag.id }) {
                state.calendarState.userTags[index] = tag
            }
            recomputeDayDisplayStates = true

        // Carries nothing to reduce — see the case's own doc comment in AppAction.swift.
        case .beganEditingUserTag:
            break

        case .markPeriodStart,
             .markPeriodEnd,
             .unmarkPeriodEnd,
             .setFlowLevel:
            break

        case .writeFailed(let operation):
            state.calendarState.writeFailure = operation

        case .dismissWriteFailure:
            state.calendarState.writeFailure = nil
        }

    case .push(let pushAction):
        switch pushAction {

        case .setAPNSToken(let token):
            state.notifications.apnsToken = token

        case .setPermissionState(let permissionState):
            state.notifications.pushPermissionState = permissionState
        }

    case .analytics(let analyticsAction):
        switch analyticsAction {

        case .checkStatus:
            break

        case .setActivated(let activated):
            state.analyticsActivated = activated
        }

    case .appearance(let appearanceAction):
        switch appearanceAction {

        case .checkAccentTheme:
            break

        case .setAccentTheme(let theme):
            state.accentTheme = theme
        }

    case .retryFailedTasks:
        break
    }

    if recomputeDayDisplayStates {
        let recomputed = computeDayDisplayStates(
            state.calendarState,
            cycleSettings: ResolvedCycleSettings(state.currentUser?.settings?.cycle)
        )

        // Compared here, once, rather than left for the readers. Most of what triggers a
        // recompute changes nothing a day is drawn with — a comment saved outside the loaded
        // range, a tag renamed — and this is the one place that can turn that into a version
        // the calendar grid then skips on. The version and the dictionary are written
        // together and nowhere else, which is what makes equal versions mean equal contents.
        if recomputed != state.calendarState.dayDisplayStates {
            state.calendarState.dayDisplayStates = recomputed
            state.calendarState.dayDisplayStatesVersion &+= 1
        }
    }

    return state
}
