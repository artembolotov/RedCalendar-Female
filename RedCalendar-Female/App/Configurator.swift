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
        registerPushPermissionsService()
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
    
    private func registerPushPermissionsService() {
        let pushPermissionsService: PushPermissionServiceProtocol = PushPermissionService()
        ServiceLocator.shared.addService(service: pushPermissionsService)
    }
}
