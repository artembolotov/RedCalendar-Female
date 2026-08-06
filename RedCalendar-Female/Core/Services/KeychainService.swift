//
//  KeychainService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Security
import Foundation

/// `nonisolated`, and that is the load-bearing part rather than a formality.
///
/// Every method here is synchronous and every one of them makes a blocking call into Security
/// framework. The module is main-actor by default, so without this the whole keychain would move
/// onto the main actor — and `.checkAuthState` reads it on the launch path, where a cold keychain
/// is the slowest it ever is. `SecItem*` is thread-safe and this type holds nothing mutable, so
/// there is nothing for the main actor to protect here; it would only be paying for the isolation.
nonisolated protocol KeychainServiceProtocol: Sendable {
    // Device ID methods (new system)
    func getDeviceID() -> String?
    @discardableResult func saveDeviceID(_ deviceId: String) -> Bool
    @discardableResult func deleteDeviceID() -> Bool

    // User UID methods (Firebase legacy, for migration)
    func getUserUID() -> String?
    @discardableResult func saveUserUID(_ uid: String) -> Bool
    @discardableResult func deleteUserUID() -> Bool
}

nonisolated final class KeychainService: KeychainServiceProtocol {

    // MARK: - Keys
    private let deviceIDKey = "redcalendar_device_id"
    private let userUIDKey = "redcalendar_user_uid"

    // MARK: - Security Configuration
    // Held as Swift types rather than `CFString`/`CFBoolean`: CoreFoundation types are not
    // `Sendable`, and the keychain queries are `[String: Any]`, which bridges either back to
    // what `SecItem*` wants.
    private let accessibility = kSecAttrAccessibleAfterFirstUnlock as String
    private let synchronizable = false

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
