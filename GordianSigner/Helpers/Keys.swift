//
//  Keys.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import LibWally

enum Keys {
    
    static func masterKey(_ words: [String], _ passphrase: String) -> String? {
        guard let mnemonic = BIP39Mnemonic(words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase)
        
        guard let hdMasterKey = HDKey(seedHex, .testnet) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
    static func masterXprv(_ words: String, _ passphrase: String) -> String? {
        guard let mnemonic = BIP39Mnemonic(words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase)
        
        guard let hdMasterKey = HDKey(seedHex, .testnet) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
    static func masterXpub(_ words: [String], _ passphrase: String) -> String? {
        guard let mnemonic = BIP39Mnemonic(words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase)
        
        guard let hdMasterKey = HDKey(seedHex, .testnet) else { return nil }
        
        return hdMasterKey.xpub
    }
    
    static func fingerprint(_ masterKey: String) -> String? {
        guard let hdMasterKey = HDKey(masterKey) else { return nil }
        
        return hdMasterKey.fingerprint.hexString
    }
    
    static func psbtValid(_ string: String) -> Bool {
        guard let _ = try? PSBT(string, .testnet) else {
            
            guard let _ = try? PSBT(string, .mainnet) else {
                return false
            }
            
            return true
        }
        
        return true
    }
    
    static func validMnemonicArray(_ words: [String]) -> Bool {
        guard let _ = BIP39Mnemonic(words) else { return false }
        
        return true
    }
    
    static func validMnemonicString(_ words: String) -> Bool {
        guard let _ = BIP39Mnemonic(words) else { return false }
        
        return true
    }
    
    static func entropy(_ words: [String]) -> Data? {
        guard let mnemonic = BIP39Mnemonic(words) else { return nil }
        
        return mnemonic.entropy.data
    }
    
    static func seed() -> String? {
        var words: String?
        let bytesCount = 16
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        if status == errSecSuccess {
            let data = Data(randomBytes)
            let hex = data.hexString
            if let entropy = BIP39Entropy(hex), let mnemonic = BIP39Mnemonic(entropy) {
                words = mnemonic.description
            }
        }
        
        return words
    }
    
    static func mnemonic(_ entropy: Data) -> String? {
        let bip39entropy = BIP39Entropy(entropy)
        
        return BIP39Mnemonic(bip39entropy)?.description        
    }
    
    static func psbt(_ psbt: String) -> PSBT? {
        guard let testnetPsbt = try? PSBT(psbt, .testnet) else {
            
            guard let mainnetPsbt = try? PSBT(psbt, .mainnet) else { return nil }
            
            return mainnetPsbt
        }
        
        return testnetPsbt
    }
}
