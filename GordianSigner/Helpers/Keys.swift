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
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase: passphrase)
        
        guard let hdMasterKey = try? HDKey(seed: seedHex, network: .mainnet) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
    static func masterXprv(_ words: String, _ passphrase: String) -> String? {
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase: passphrase)
        
        guard let hdMasterKey = try? HDKey(seed: seedHex, network: .mainnet) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
    static func masterXpub(_ words: [String], _ passphrase: String) -> String? {
        guard let mnemonic = try? BIP39Mnemonic(words: words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase: passphrase)
        
        guard let hdMasterKey = try? HDKey(seed: seedHex, network: .mainnet) else { return nil }
        
        return hdMasterKey.xpub
    }
    
    static func fingerprint(_ masterKey: String) -> String? {
        guard let hdMasterKey = try? HDKey(base58: masterKey) else { return nil }
        
        return hdMasterKey.fingerprint.hexString
    }
    
    static func psbtValid(_ string: String) -> Bool {
        guard let _ = try? PSBT(psbt: string, network: .mainnet) else {
            
            guard let _ = try? PSBT(psbt: string, network: .mainnet) else {
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
    
    static func psbt(_ psbt: String, _ network: Network) -> PSBT? {
        
        return try? PSBT(psbt: psbt, network: network)
    }
    
    static func psbt(_ psbt: Data, _ network: Network) -> PSBT? {
        
        return try? PSBT(psbt: psbt, network: network)
    }
    
    static func bip44Account(_ masterKey: String, _ network: String) -> String? {
        var coinType = "1"
        
        switch network {
        case "main":
            coinType = "0"
        default:
            break
        }
                
        guard let hdKey = try? HDKey(base58: masterKey), let bip44deriv = try? BIP32Path(string: "m/44'/\(coinType)'/0'"),
            let account = try? hdKey.derive(using: bip44deriv) else {
                return nil
        }
                        
        return "[\(hdKey.fingerprint.hexString)/44h/\(coinType)h/0h]\(account.xpub)"
    }
    
    static func bip45Account(_ masterKey: String) -> String? {
        guard let hdKey = try? HDKey(base58: masterKey), let bip45deriv = try? BIP32Path(string: "m/45'"),
            let account = try? hdKey.derive(using: bip45deriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/45h]\(account.xpub)"
    }
    
    static func bip84Account(_ masterKey: String, _ network: String) -> String? {
        var coinType = "1"
        
        switch network {
        case "main":
            coinType = "0"
        default:
            break
        }
                
        guard let hdKey = try? HDKey(base58: masterKey), let bip84deriv = try? BIP32Path(string: "m/84'/\(coinType)'/0'"),
            let account = try? hdKey.derive(using: bip84deriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/84h/\(coinType)h/0h]\(account.xpub)"
    }
    
    static func bip49Account(_ masterKey: String, _ network: String) -> String? {
        var coinType = "1"
        
        switch network {
        case "main":
            coinType = "0"
        default:
            break
        }
                
        guard let hdKey = try? HDKey(base58: masterKey), let bip49deriv = try? BIP32Path(string: "m/49'/\(coinType)'/0'"),
            let account = try? hdKey.derive(using: bip49deriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/49h/\(coinType)h/0h]\(account.xpub)"
    }
    
    static func bip48LegacyAccount(_ masterKey: String, _ network: String) -> String? {
        var coinType = "1"
        
        switch network {
        case "main":
            coinType = "0"
        default:
            break
        }
                
        guard let hdKey = try? HDKey(base58: masterKey), let bip48LegacyDeriv = try? BIP32Path(string: "m/48'/\(coinType)'/0'/1'"),
            let account = try? hdKey.derive(using: bip48LegacyDeriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/48h/\(coinType)h/0h/1h]\(account.xpub)"
    }
    
    static func bip48SegwitAccount(_ masterKey: String, _ network: String) -> String? {
        var coinType = "1"
        
        switch network {
        case "main":
            coinType = "0"
        default:
            break
        }
                
        guard let hdKey = try? HDKey(base58: masterKey), let bip48SegwitDeriv = try? BIP32Path(string: "m/48'/\(coinType)'/0'/2'"),
            let account = try? hdKey.derive(using: bip48SegwitDeriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/48h/\(coinType)h/0h/2h]\(account.xpub)"
    }
    
    static func bip48NestedAccount(_ masterKey: String, _ network: String) -> String? {
        var coinType = "1"
        
        switch network {
        case "main":
            coinType = "0"
        default:
            break
        }
                
        guard let hdKey = try? HDKey(base58: masterKey), let bip48NestedDeriv = try? BIP32Path(string: "m/48'/\(coinType)'/0'/3'"),
            let account = try? hdKey.derive(using: bip48NestedDeriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/48h/\(coinType)h/0h/3h]\(account.xpub)"
    }
}
