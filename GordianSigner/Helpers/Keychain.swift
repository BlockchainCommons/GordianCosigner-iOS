//
//  Keychain.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

enum KeyChain {

    static func set(_ data: Data, forKey: String) -> Bool {
        let query = [
            kSecClass as String       : kSecClassGenericPassword as String,
            kSecAttrSynchronizable as String : kCFBooleanTrue!,
            kSecAttrAccessible as String : kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccessGroup as String: "YZHG975W3A.com.blockchaincommons.GordianSigner",
            kSecAttrAccount as String : forKey,
            kSecValueData as String   : data ] as [String : Any]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == noErr {
            return true
        } else {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Set failed: \(err)")
                print(err)
            }
            return false
        }
    }

    static func getData(_ key: String) -> Data? {
        let query = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecAttrAccessible as String : kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String : kCFBooleanTrue!,
            kSecAttrAccessGroup as String: "YZHG975W3A.com.blockchaincommons.GordianSigner",
            kSecMatchLimit as String  : kSecMatchLimitOne ] as [String : Any]

        var dataTypeRef: AnyObject? = nil

        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == noErr {
            return dataTypeRef as! Data?
        } else {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Get failed: \(err)")
            }
            return nil
        }
    }
    
    static func remove(key: String) -> Bool {
        let query = [
            kSecClass as String       : kSecClassGenericPassword as String,
            kSecAttrSynchronizable as String : kCFBooleanTrue!,
            kSecAttrAccessible as String : kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccount as String : key] as [String : Any]

        // Delete any existing items
        let status = SecItemDelete(query as CFDictionary)
        if (status != errSecSuccess) {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Remove failed: \(err)")
            }
            return false
        } else {
            return true
        }

    }
    
    static func removeAll() {
        let secItemClasses =  [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            SecItemDelete(spec)
        }
    }

    private func createUniqueID() -> String {
        let uuid: CFUUID = CFUUIDCreate(nil)
        let cfStr: CFString = CFUUIDCreateString(nil, uuid)

        let swiftString: String = cfStr as String
        return swiftString
    }
}
