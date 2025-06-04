//
//  KeychainService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Security
import Foundation

protocol KeychainServiceProtocol {
    func getUserUID() -> String?
    @discardableResult func saveUserUID(_ uid: String) -> Bool
    @discardableResult func deleteUserUID() -> Bool
}

final class KeychainService: KeychainServiceProtocol {
    private let userUIDKey = "redcalendar_user_uid"
    
    func getUserUID() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userUIDKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let uid = String(data: data, encoding: .utf8) {
            return uid
        }
        
        return nil
    }
    
    func saveUserUID(_ uid: String) -> Bool {
        guard let data = uid.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userUIDKey,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func deleteUserUID() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userUIDKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
