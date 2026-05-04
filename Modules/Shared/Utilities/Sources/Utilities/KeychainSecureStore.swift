//
//  KeychainSecureStore.swift
//  cisum
//
//  Created by Aarav Gupta on 26/04/26.
//

import Foundation
import Security
import Foundation
import Security
import YouTubeSDK

#warning("Will remove Apple Frameworks from SDK later")
/// An Apple-specific implementation of secure storage using the Security framework.
/// This implementation conforms to YouTubeSecureStore protocol to bridge the gap.
//public struct AppleKeychainStore: Sendable, YouTubeSecureStore {
//    
//    public init() {}
//    
//    // MARK: - YouTubeSecureStore
//    
//    public func save(_ value: String, key: String) async {
//        // We use a fixed service name for YouTubeSDK within this app context.
//        save(value, key: key, service: "aaravgupta.youtubesdk.security")
//    }
//    
//    public func load(key: String) async -> String? {
//        load(key: key, service: "aaravgupta.youtubesdk.security")
//    }
//    
//    public func delete(key: String) async {
//        delete(key: key, service: "aaravgupta.youtubesdk.security")
//    }
//    
//    // MARK: - Internal Implementation
//    
//    private func save(_ value: String, key: String, service: String) {
//
//        guard let data = value.data(using: .utf8) else { return }
//        
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: key,
//            kSecValueData as String: data,
//            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
//        ]
//        
//        SecItemDelete(query as CFDictionary)
//        SecItemAdd(query as CFDictionary, nil)
//    }
//    
//    private func load(key: String, service: String) -> String? {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: key,
//            kSecReturnData as String: true,
//            kSecMatchLimit as String: kSecMatchLimitOne
//        ]
//        
//        var dataTypeRef: AnyObject?
//        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
//        
//        if status == errSecSuccess, let data = dataTypeRef as? Data {
//            return String(data: data, encoding: .utf8)
//        }
//        return nil
//    }
//    
//    private func delete(key: String, service: String) {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: key
//        ]
//        SecItemDelete(query as CFDictionary)
//    }
//}
