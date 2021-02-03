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
    
    static let chain:Network = .testnet
    static let coinType = "1"
    
    static func accountXprv(_ masterKey: String) -> String? {
        guard let hdkey = try? HDKey(base58: masterKey), let path = try? BIP32Path(string: "m/48h/\(coinType)h/0h/2h"), let accountXprv = try? hdkey.derive(using: path) else {
            return nil
        }
                
        return accountXprv.xpriv
    }
    
    static func accountXpub(_ masterKey: String) -> String? {
        guard let hdkey = try? HDKey(base58: masterKey), let path = try? BIP32Path(string: "m/48h/\(coinType)h/0h/2h"), let accountXpub = try? hdkey.derive(using: path) else {
            return nil
        }
        
        return accountXpub.xpub
    }
    
    static func masterKey(_ words: [String], _ passphrase: String) -> String? {
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase: passphrase)
        
        guard let hdMasterKey = try? HDKey(seed: seedHex, network: chain) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
    static func masterXprv(_ words: String, _ passphrase: String) -> String? {
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase: passphrase)
        
        guard let hdMasterKey = try? HDKey(seed: seedHex, network: chain) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
    static func masterXpub(_ words: [String], _ passphrase: String) -> String? {
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase: passphrase)
        
        guard let hdMasterKey = try? HDKey(seed: seedHex, network: chain) else { return nil }
        
        return hdMasterKey.xpub
    }
    
    static func fingerprint(_ masterKey: String) -> String? {
        guard let hdMasterKey = try? HDKey(base58: masterKey) else { return nil }
        
        return hdMasterKey.fingerprint.hexString
    }
    
    static func psbtValid(_ string: String) -> Bool {
        guard let _ = try? PSBT(psbt: string, network: chain) else {
            
            guard let _ = try? PSBT(psbt: string, network: chain) else {
                return false
            }
            
            return true
        }
        
        return true
    }
    
    static func validMnemonicArray(_ words: [String]) -> Bool {
        guard let _ = try? BIP39Mnemonic(words: words) else { return false }
        
        return true
    }
    
    static func validMnemonicString(_ words: String) -> Bool {
        guard let _ = try? BIP39Mnemonic(words: words) else { return false }
        
        return true
    }
    
    static func entropy(_ words: [String]) -> Data? {
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        return mnemonic.entropy.data
    }
    
    static func entropy(_ words: String) -> Data? {
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        return mnemonic.entropy.data
    }
    
    static func seed() -> String? {
        var words: String?
        let bytesCount = 16
        var randomBytes = [UInt8](repeating: 0, count: bytesCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytesCount, &randomBytes)
        
        if status == errSecSuccess {
            let data = Data(randomBytes)
            let entropy = BIP39Mnemonic.Entropy(data)
            if let mnemonic = try? BIP39Mnemonic(entropy: entropy) {
                words = mnemonic.description
            }
        }
        
        return words
    }
    
    static func mnemonic(_ entropy: Data) -> String? {
        let bip39entropy = BIP39Mnemonic.Entropy(entropy)

        return try? BIP39Mnemonic(entropy: bip39entropy).description
    }
    
    static func psbt(_ psbt: String) -> PSBT? {
        
        return try? PSBT(psbt: psbt, network: chain)
    }
    
    static func psbt(_ psbt: Data) -> PSBT? {
        
        return try? PSBT(psbt: psbt, network: chain)
    }
    
    static func bip48SegwitAccount(_ masterKey: String) -> String? {
        guard let hdKey = try? HDKey(base58: masterKey), let bip48SegwitDeriv = try? BIP32Path(string: "m/48'/\(coinType)'/0'/2'"),
            let account = try? hdKey.derive(using: bip48SegwitDeriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/48h/\(coinType)h/0h/2h]\(account.xpub)"
    }
    
    static func bip48SegwitAccountXprv(_ masterKey: String) -> String? {
        guard let hdKey = try? HDKey(base58: masterKey), let bip48SegwitDeriv = try? BIP32Path(string: "m/48'/\(coinType)'/0'/2'"),
              let account = try? hdKey.derive(using: bip48SegwitDeriv), let xprv = account.xpriv else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/48h/\(coinType)h/0h/2h]\(xprv)"
    }
}
