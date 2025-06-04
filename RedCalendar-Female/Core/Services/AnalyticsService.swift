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
}
