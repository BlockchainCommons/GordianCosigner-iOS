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
    
    static func psbt(_ psbt: String, _ network: Network) -> PSBT? {
        
        return try? PSBT(psbt, network)
    }
    
    static func bip44Account(_ masterKey: String, _ network: String) -> String? {
        var coinType = "1"
        
        switch network {
        case "main":
            coinType = "0"
        default:
            break
        }
                
        guard let hdKey = HDKey(masterKey), let bip44deriv = BIP32Path("m/44'/\(coinType)'/0'"),
            let account = try? hdKey.derive(bip44deriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/44h/\(coinType)h/0h]\(account.xpub)"
    }
    
    static func bip45Account(_ masterKey: String) -> String? {
        guard let hdKey = HDKey(masterKey), let bip45deriv = BIP32Path("m/45'"),
            let account = try? hdKey.derive(bip45deriv) else {
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
                
        guard let hdKey = HDKey(masterKey), let bip84deriv = BIP32Path("m/84'/\(coinType)'/0'"),
            let account = try? hdKey.derive(bip84deriv) else {
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
                
        guard let hdKey = HDKey(masterKey), let bip49deriv = BIP32Path("m/49'/\(coinType)'/0'"),
            let account = try? hdKey.derive(bip49deriv) else {
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
                
        guard let hdKey = HDKey(masterKey), let bip48LegacyDeriv = BIP32Path("m/48'/\(coinType)'/0'/1'"),
            let account = try? hdKey.derive(bip48LegacyDeriv) else {
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
                
        guard let hdKey = HDKey(masterKey), let bip48SegwitDeriv = BIP32Path("m/48'/\(coinType)'/0'/2'"),
            let account = try? hdKey.derive(bip48SegwitDeriv) else {
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
                
        guard let hdKey = HDKey(masterKey), let bip48NestedDeriv = BIP32Path("m/48'/\(coinType)'/0'/3'"),
            let account = try? hdKey.derive(bip48NestedDeriv) else {
                return nil
        }
                
        return "[\(hdKey.fingerprint.hexString)/48h/\(coinType)h/0h/3h]\(account.xpub)"
    }
}
