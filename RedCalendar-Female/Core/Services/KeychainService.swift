//
//  KeychainService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Security
import Foundation

protocol KeychainServiceProtocol {
    // Device ID methods (new system)
    func getDeviceID() -> String?
    @discardableResult func saveDeviceID(_ deviceId: String) -> Bool
    @discardableResult func deleteDeviceID() -> Bool
    
    // User UID methods (Firebase legacy, for migration)
    func getUserUID() -> String?
    @discardableResult func saveUserUID(_ uid: String) -> Bool
    @discardableResult func deleteUserUID() -> Bool
}

final class KeychainService: KeychainServiceProtocol {
    
    // MARK: - Keys
    private let deviceIDKey = "redcalendar_device_id"
    private let userUIDKey = "redcalendar_user_uid"
    
    // MARK: - Device ID Methods (New System)
    func getDeviceID() -> String? {
        return getValue(for: deviceIDKey)
    }
    
    func saveDeviceID(_ deviceId: String) -> Bool {
        return setValue(deviceId, for: deviceIDKey)
    }
    
    func deleteDeviceID() -> Bool {
        return deleteValue(for: deviceIDKey)
    }
    
    // MARK: - User UID Methods (Legacy Firebase)
    func getUserUID() -> String? {
        return getValue(for: userUIDKey)
    }
    
    func saveUserUID(_ uid: String) -> Bool {
        return setValue(uid, for: userUIDKey)
    }
    
    func deleteUserUID() -> Bool {
        return deleteValue(for: userUIDKey)
    }
    
    // MARK: - Private Helpers
    private func getValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    private func setValue(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func deleteValue(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
