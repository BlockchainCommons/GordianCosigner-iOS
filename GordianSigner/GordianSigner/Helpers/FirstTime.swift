//
//  FirstTime.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

enum FirstTime {
        
    static func firstTimeHere() -> Bool {
        if KeyChain.getData("privateKey") == nil {
            let privateKey = Encryption.privateKey()
            let success = KeyChain.set(privateKey, forKey: "privateKey")
            
            #if DEBUG
                print("set master encryption key: \(success)")
            #endif
            
            return success
        } else {
            
            return true
        }
    }
    
}
