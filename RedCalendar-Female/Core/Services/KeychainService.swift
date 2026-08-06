//
//  KeychainService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

@preconcurrency import Security
import Foundation

protocol KeychainServiceProtocol: Sendable {
    // Device ID methods (new system)
    func getDeviceID() -> String?
    @discardableResult func saveDeviceID(_ deviceId: String) -> Bool
    @discardableResult func deleteDeviceID() -> Bool
    
    // User UID methods (Firebase legacy, for migration)
    func getUserUID() -> String?
    @discardableResult func saveUserUID(_ uid: String) -> Bool
    @discardableResult func deleteUserUID() -> Bool
}

final class KeychainService: KeychainServiceProtocol, Sendable {
    
    // MARK: - Keys
    private let deviceIDKey = "redcalendar_device_id"
    private let userUIDKey = "redcalendar_user_uid"
    
    // MARK: - Security Configuration
    private let accessibility = kSecAttrAccessibleAfterFirstUnlock
    private let synchronizable: CFBoolean = kCFBooleanFalse
    
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
            kSecAttrSynchronizable as String: synchronizable,
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
        
        if status != errSecItemNotFound && status != errSecSuccess {
            AppLogger.error("Keychain read error for key: \(key), status: \(status)")
        }
        
        return nil
    }
    
    private func setValue(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            AppLogger.error("Failed to convert value to data for key: \(key)")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: synchronizable,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]
        
        // Delete existing item first to avoid conflicts
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            AppLogger.error("Keychain delete warning for key: \(key), status: \(deleteStatus)")
        }
        
        // Add new item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        if addStatus != errSecSuccess {
            AppLogger.error("Keychain save error for key: \(key), status: \(addStatus)")
        }
        
        return addStatus == errSecSuccess
    }
    
    private func deleteValue(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            AppLogger.error("Keychain delete error for key: \(key), status: \(status)")
        }
        
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
