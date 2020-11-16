//
//  SignerStruct.swift
//  GordianSigner
//
//  Created by Peter on 11/11/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

public struct SignerStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let entropy:Data?
    let passphrase:Data?
    let dateAdded:Date
    let lifeHash:Data
    let fingerprint:String
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as! String
        entropy = dictionary["entropy"] as? Data
        passphrase = dictionary["passphrase"] as? Data
        dateAdded = dictionary["dateAdded"] as! Date
        lifeHash = dictionary["lifeHash"] as! Data
        fingerprint = dictionary["fingerprint"] as! String
    }
    
    public var description: String {
        return ""
    }
}
