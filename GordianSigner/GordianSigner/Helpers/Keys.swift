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
    
    static func masterKey(words: String, passphrase: String) -> String? {
        guard let mnemonic = BIP39Mnemonic(words) else { return nil }
        
        let seedHex = mnemonic.seedHex(passphrase)
        
        guard let hdMasterKey = HDKey(seedHex, .testnet) else { return nil }
        
        return hdMasterKey.xpriv
    }
    
}
