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
    
    static func masterKey(_ words: String, _ passphrase: String) -> String? {
        guard let mnemonic = BIP39Mnemonic(words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase)
        
        guard let hdMasterKey = HDKey(seedHex, .testnet) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
    static func fingerprint(_ masterKey: String) -> String? {
        guard let hdMasterKey = HDKey(masterKey) else { return nil }
        
        return hdMasterKey.fingerprint.hexString
    }
    
    static func psbtValid(_ string: String) -> Bool {
        guard let _ = try? PSBT(string, .testnet) else { return false }
        
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
    
}
