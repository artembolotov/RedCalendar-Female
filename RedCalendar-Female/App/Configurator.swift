//
//  Configurator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

final class Configurator {
    static let shared = Configurator()
    
    private init() {}
    
    func setup() {
        registerAnalyticsService()
        registerKeychainService()
        registerAPIService()
        registerPushService()
    }
    
    private func registerAnalyticsService() {
        let analytics: any AnalyticsServiceProtocol = AnalyticsService()
        ServiceLocator.shared.addService(service: analytics)
        
        analytics.registerApp()
    }
    
    private func registerKeychainService() {
        let keychain: KeychainServiceProtocol = KeychainService()
        ServiceLocator.shared.addService(service: keychain)
    }
    
    private func registerAPIService() {
        let apiService: APIServiceProtocol = APIService()
        ServiceLocator.shared.addService(service: apiService)
    }
    
    private func registerPushService() {
        let pushService: PushServiceProtocol = PushService()
        ServiceLocator.shared.addService(service: pushService)
        
        pushService.registerForRemoteNotifications()
    }
}
