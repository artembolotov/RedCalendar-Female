//
//  AnalyticsService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import AppMetricaCore

protocol AnalyticsServiceProtocol: Sendable {
    var isActivated: Bool { get }
    func registerApp()
    func trackEvent(_ name: String)
    func trackEvent(_ name: String, parameters: [AnyHashable : Any]?)
}

final class AnalyticsService: AnalyticsServiceProtocol, Sendable {

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

    func trackEvent(_ name: String, parameters: [AnyHashable : Any]?) {
        AppMetrica.reportEvent(name: name, parameters: parameters)
    }
}
