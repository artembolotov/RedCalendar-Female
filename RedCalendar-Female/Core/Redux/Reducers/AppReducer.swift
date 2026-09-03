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
                // The preference belongs to the account that has just gone, and the row it was
                // read from is wiped with it (§6). Left standing at `.enabled`, it would be one
                // half of the condition that puts the system permission alert on screen, and the
                // next person to sign in on this phone would be asked on the strength of a
                // choice somebody else made.
                state.notifications.preference = .unknown
                state.calendarState = CalendarState()
                state.syncState = .idle
                // The row behind it is wiped on logout (§6) and belongs to the previous account
                // after any sign-out; left here it would still be the name and the cycle
                // settings the next screen reads.
                state.userProfile = nil
                state.cycleSettings = ResolvedCycleSettings(nil)
                // The screen belongs to the account that has just gone, and a code in flight was
                // sent on its behalf. Left standing, the sheet would reopen over the welcome
                // screen on the next sign-in with somebody else's address in the field.
                state.emailBinding = nil
                // The list belongs to the account that has just gone, and a revocation in flight
                // was asked for on its behalf.
                state.devices = nil
            }

        case .logout, .deleteAccount:
            break

        case .completedRegistrationOnboarding:
            if case .authenticated(let deviceId, _) = state.authState {
                state.authState = .authenticated(deviceId: deviceId)
            }
        }

    case .emailBinding(let bindingAction):
        switch bindingAction {

        case .set(let bindingState):
            switch (state.emailBinding, bindingState) {
            // Opening the screen — the only transition allowed to start from a closed one.
            case (nil, .some(.entry)):
                state.emailBinding = bindingState

            // A request that lands after the person closed the sheet does not reopen it. The
            // flow's one lasting effect is the address, and that arrives on `userProfile` by the
            // sync pull whether or not anybody is still watching (§4.4) — so the answer has
            // nowhere it needs to be shown.
            case (nil, _):
                break

            default:
                state.emailBinding = bindingState
            }
        }

    case .devices(let devicesAction):
        switch devicesAction {

        case .load:
            // Opening the screen. The previous list, if the screen is being reopened, is gone
            // with it — showing yesterday's sessions while today's are being fetched is the one
            // thing a list of live sessions must not do.
            state.devices = DevicesState(isLoading: true)

        case .setDevices(let devices):
            state.devices?.devices = devices
            state.devices?.isLoading = false
            state.devices?.failure = nil

        case .loadFailed:
            state.devices?.isLoading = false
            state.devices?.failure = .load

        case .close:
            state.devices = nil

        case .revoke(let deviceId):
            state.devices?.revoking.insert(deviceId)
            state.devices?.failure = nil

        case .revoked(let deviceId):
            // The row goes here rather than on a re-fetch: the answer already says this session
            // is gone, and asking the server again to be told the same thing costs a request and
            // a moment of the list flickering.
            state.devices?.revoking.remove(deviceId)
            state.devices?.devices.removeAll { $0.id == deviceId }

        case .revokeFailed(let deviceId):
            state.devices?.revoking.remove(deviceId)
            state.devices?.failure = .revoke
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

        // Nothing drawn depends on the identity half of the profile, so no recompute here. The
        // half that is drawn arrives as its own action below.
        case .setUserProfile(let profile):
            state.userProfile = profile

        // Rebuilt here, because settings changed on another device would otherwise only take
        // effect at the next unrelated cycle/tag/comment change.
        case .setCycleSettings(let cycle):
            state.cycleSettings = ResolvedCycleSettings(cycle)
            recomputeDayDisplayStates = true

        // Nothing is drawn from it — it is a switch's position and a precondition for asking iOS
        // for permission — so no recompute.
        case .setNotificationPreference(let preference):
            state.notifications.preference = preference

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

        // Written, never reduced. Unlike a comment, the value being edited is not on its way to
        // a card underneath a dismissing sheet: `SettingsView` holds its own draft while the
        // steppers are being tapped and the store hears about it once, at the end, so there is
        // nothing to put on screen ahead of the disk — and nothing to put back if the write
        // fails.
        case .markPeriodStart,
             .markPeriodEnd,
             .unmarkPeriodEnd,
             .setFlowLevel,
             .setCycleLength,
             .setPeriodLength,
             .setAutoConfirmPreviousCycle,
             .setName,
             // The switch holds its own position while the write goes round — same reason, and
             // the same consequence: there is nothing here to put back if the write fails.
             .setNotificationsEnabled:
            break

        case .writeFailed(let operation):
            state.calendarState.writeFailure = operation

        case .dismissWriteFailure:
            state.calendarState.writeFailure = nil
        }

    case .sync(let syncAction):
        switch syncAction {

        // The run's own progress lives on the disk — cursor, owner, dirty flags — because it has
        // to survive a launch. Nothing here but what is drawn.
        case .requested, .beganFullResync, .finishedFullResync:
            break

        case .setState(let syncState):
            state.syncState = syncState
        }

    case .push(let pushAction):
        switch pushAction {

        case .setAPNSToken(let token):
            state.notifications.apnsToken = token

        case .checkPermissionState:
            break

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
            cycleSettings: state.cycleSettings
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
