//
//  NotificationState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 21.05.2026.
//

nonisolated struct NotificationState: Equatable, Sendable {
    var apnsToken: APNSToken?
    var pushPermissionState: PushPermissionState?
}
