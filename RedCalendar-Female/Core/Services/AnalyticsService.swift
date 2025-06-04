//
//  AnalyticsService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import AppMetricaCore

protocol AnalyticsServiceProtocol {
    func registerApp()
    func trackEvent(_ name: String)
    func trackEvent(_ name: String, parameters: [AnyHashable : Any]?)
}

final class AnalyticsService: AnalyticsServiceProtocol {
    
    private let apiKey = "***REMOVED***"
    
    func registerApp() {
        let configuration = AppMetricaConfiguration(apiKey: apiKey)
        AppMetrica.activate(with: configuration!)
    }
    
    func trackEvent(_ name: String) {
        AppMetrica.reportEvent(name: name)
    }
    
    func trackEvent(_ name: String, parameters: [AnyHashable : Any]?) {
        AppMetrica.reportEvent(name: name, parameters: parameters)
    }
}
