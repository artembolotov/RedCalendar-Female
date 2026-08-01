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
        registerDatabaseService()
        registerKeychainService()
        registerAPIService()
        registerPushPermissionsService()
        registerTapticFeedbackService()
        registerAppearanceService()
    }
    
    private func registerAnalyticsService() {
        let analytics: any AnalyticsServiceProtocol = AnalyticsService()
        ServiceLocator.shared.addService(service: analytics)
        
        analytics.registerApp()
    }
    
    private func registerDatabaseService() {
        do {
            let dbService: DatabaseServiceProtocol = try DatabaseService()
            ServiceLocator.shared.addService(service: dbService)
        } catch {
            fatalError("Failed to initialize DatabaseService: \(error)")
        }
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
    
    private func registerTapticFeedbackService() {
        let tapticFeedbackService: TapticFeedbackServiceProtocol = TapticFeedbackService()
        ServiceLocator.shared.addService(service: tapticFeedbackService)
    }

    private func registerAppearanceService() {
        let appearanceService: AppearanceServiceProtocol = AppearanceService()
        ServiceLocator.shared.addService(service: appearanceService)
    }
}
