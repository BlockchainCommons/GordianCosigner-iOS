//
//  Keychain.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

enum KeyChain {
    
    static func seeds() -> [Data]? {
        guard let seeds = KeyChain.getSeed("seeds") else { return nil }
        
        return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(seeds) as? [Data]
    }
    
    static func overWriteExistingSeeds(_ unencryptedSeeds: [String], completion: @escaping ((Bool)) -> Void) {
        var encrpytedSeeds = [Data]()
        
        for (i, unencryptedSeed) in unencryptedSeeds.enumerated() {
            guard let unencryptedData = unencryptedSeed.data(using: .utf8),
                let encryptedData = Encryption.encrypt(unencryptedData) else { completion((false)); return }
            
            encrpytedSeeds.append(encryptedData)
            
            if i + 1 == unencryptedSeeds.count {
                
                do {
                    let updatedEncryptedSeedArray = try NSKeyedArchiver.archivedData(withRootObject: encrpytedSeeds, requiringSecureCoding: true)
                    
                    completion(KeyChain.setSeed(updatedEncryptedSeedArray, forKey: "seeds"))
                } catch {
                    
                    completion(false)
                }
            }
        }
    }
    
    static func saveNewSeed(_ encryptedSeed: Data) -> Bool {
        guard let seeds = KeyChain.seeds() else {
            /// Seed has never been added.
            do {
                let updatedEncryptedSeedArray = try NSKeyedArchiver.archivedData(withRootObject: [encryptedSeed], requiringSecureCoding: true)
                
                return KeyChain.setSeed(updatedEncryptedSeedArray, forKey: "seeds")
            } catch {
                
                return false
            }
        }
        
        var existingEncryptedSeeds = seeds
        existingEncryptedSeeds.append(encryptedSeed)
        
        do {
            let updatedEncryptedSeedArray = try NSKeyedArchiver.archivedData(withRootObject: existingEncryptedSeeds, requiringSecureCoding: true)
            
            return KeyChain.setSeed(updatedEncryptedSeedArray, forKey: "seeds")
        } catch {
            
            return false
        }
    }
    
    static func setSeed(_ data: Data, forKey: String) -> Bool {
        let query = [
            kSecClass as String       : kSecClassGenericPassword as String,
            kSecAttrSynchronizable as String : kCFBooleanFalse!,
            kSecAttrAccessible as String : kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccount as String : forKey,
            kSecValueData as String   : data ] as [String : Any]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == noErr {
            return true
        } else {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Set failed: \(err)")
            }
            return false
        }
    }
    
    static func getSeed(_ key: String) -> Data? {
        let query = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecAttrAccessible as String : kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String : kCFBooleanFalse!,
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

    static func set(_ data: Data, forKey: String) -> Bool {
        let query = [
            kSecClass as String       : kSecClassGenericPassword as String,
            //kSecAttrSynchronizable as String : kCFBooleanTrue!,
            kSecAttrAccessible as String : kSecAttrAccessibleAfterFirstUnlock,
            //kSecAttrAccessGroup as String: "YZHG975W3A.com.blockchaincommons.sharedItems",
            kSecAttrAccount as String : forKey,
            kSecValueData as String   : data ] as [String : Any]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == noErr {
            return true
        } else {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Set failed: \(err)")
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
            //kSecAttrSynchronizable as String : kCFBooleanTrue!,
            //kSecAttrAccessGroup as String: "YZHG975W3A.com.blockchaincommons.sharedItems",
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
            //kSecAttrSynchronizable as String : kCFBooleanTrue!,
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
