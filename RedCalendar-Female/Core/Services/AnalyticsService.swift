//
//  AnalyticsService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import AppMetricaCore

/// `parameters` is `[String: String]` rather than AppMetrica's own `[AnyHashable: Any]`, which is
/// the one signature in the service layer that can never be `Sendable` — an `Any` value carries no
/// guarantee at all, so a dictionary of them cannot cross an isolation boundary. Both call sites
/// (`AppLogger.warn`, `AppLogger.error`) pass a single `["message": String]`, so nothing is given
/// up; the upcast to AppMetrica's type happens once, at the call into the SDK.
protocol AnalyticsServiceProtocol {
    var isActivated: Bool { get }
    func registerApp()
    func trackEvent(_ name: String)
    func trackEvent(_ name: String, parameters: [String: String]?)
}

final class AnalyticsService: AnalyticsServiceProtocol {

    var isActivated: Bool { AppMetrica.isActivated }

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "APPMETRICA_API_KEY") as? String ?? ""
    }

    func registerApp() {
        guard !apiKey.isEmpty,
              let configuration = AppMetricaConfiguration(apiKey: apiKey) else { return }
        AppMetrica.activate(with: configuration)
    }

    func trackEvent(_ name: String) {
        AppMetrica.reportEvent(name: name)
    }

    func trackEvent(_ name: String, parameters: [String: String]?) {
        AppMetrica.reportEvent(name: name, parameters: parameters.map { $0 as [AnyHashable: Any] })
    }
}
