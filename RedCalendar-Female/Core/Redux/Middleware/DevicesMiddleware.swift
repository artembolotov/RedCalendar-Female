//
//  DevicesMiddleware.swift
//  RedCalendar-Female
//

import Foundation

/// The account's sessions (SYNC.md §19): read the list, drop one of them.
///
/// It owns the `devices` domain, so the inner switch is exhaustive, and only two of its cases
/// reach the network — the rest are answers coming back. Nothing here is stored: the list is read
/// while the screen is open and dropped by the reducer when it closes.
let devicesMiddleware: Middleware = { state, action, dispatch in
    @Injected var apiService: APIServiceProtocol

    guard case .devices(let devicesAction) = action else { return }

    switch devicesAction {

    case .load:
        // Both endpoints are behind the device token, so a screen open without a session has
        // nothing to ask. It cannot normally happen — the screen is one push inside Settings,
        // which itself draws nothing without a `deviceId` — but returning here would leave the
        // spinner the reducer has already switched on with nothing to switch it off: the
        // middleware sees the state its own action produced (see `AppStore`), so `isLoading` is
        // true by now. Answering is what ends that.
        guard let deviceId = state.deviceId else {
            AppLogger.warn("Device list asked for without a session")
            dispatch(.devices(.loadFailed))
            return
        }

        Task {
            do {
                let response = try await apiService.listDevices(deviceId: deviceId)

                guard response.success, let data = response.data else {
                    throw APIServiceError.serverError(response.message ?? "Device list failed")
                }

                dispatch(.devices(.setDevices(data.devices.map(UserDevice.init(entry:)))))

            } catch {
                // What the person can do about any of these is the same — try again — so the
                // reason goes to the log rather than onto the screen. A 401 is not signed out
                // from here either: that rule lives in `SyncMiddleware` (§6), and the next run
                // applies it.
                AppLogger.error("Device list failed", error: error)
                dispatch(.devices(.loadFailed))
            }
        }

    case .revoke(let targetDeviceId):
        // Same as above, and the row rather than the screen is what would hang: the reducer has
        // already put this id into `revoking`, and only an answer takes it back out.
        guard let deviceId = state.deviceId else {
            AppLogger.warn("Device revocation asked for without a session")
            dispatch(.devices(.revokeFailed(deviceId: targetDeviceId)))
            return
        }

        Task {
            do {
                let response = try await apiService.revokeDevice(
                    deviceId: deviceId,
                    targetDeviceId: targetDeviceId
                )

                guard response.success else {
                    throw APIServiceError.serverError(response.message ?? "Device revocation failed")
                }

                dispatch(.devices(.revoked(deviceId: targetDeviceId)))

            } catch APIServiceError.refused(let refusal) where refusal.error == "DEVICE_NOT_FOUND" {
                // Already gone — another device revoked it, or this request was sent twice. That
                // is the outcome that was asked for, so the row goes rather than the row staying
                // with an error under it.
                AppLogger.info("Device \(targetDeviceId) was already off the account")
                dispatch(.devices(.revoked(deviceId: targetDeviceId)))

            } catch {
                AppLogger.error("Device revocation failed", error: error)
                dispatch(.devices(.revokeFailed(deviceId: targetDeviceId)))
            }
        }

    // Answers and screen lifecycle: the reducer's, not this one's. Spelled out rather than swept
    // into a `default`, so a new case here is a build error in this file.
    case .setDevices, .loadFailed, .close, .revoked, .revokeFailed:
        break
    }
}

private extension UserDevice {
    init(entry: DeviceListResponse.DeviceEntry) {
        self.init(
            id: entry.deviceId,
            name: entry.name,
            lastSeenAt: entry.lastSeenAt.flatMap(Self.parseTimestamp)
        )
    }

    /// The server sends `toISOString()`, which always carries milliseconds — but the formatter
    /// without `.withFractionalSeconds` rejects exactly that, so both are tried.
    static func parseTimestamp(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
