//
//  KeysetStruct.swift
//  GordianSigner
//
//  Created by Peter on 11/15/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

public struct KeysetStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let bip48SegwitAccount:String?
    let dateAdded:Date
    let dateShared:Date?
    let sharedWith:UUID?
    let fingerprint:String
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as! String
        bip48SegwitAccount = dictionary["bip48SegwitAccount"] as? String
        dateAdded = dictionary["dateAdded"] as! Date
        dateShared = dictionary["dateShared"] as? Date
        sharedWith = dictionary["sharedWith"] as? UUID
        fingerprint = dictionary["fingerprint"] as? String ?? "00000000"
    }
    
    public var description: String {
        return ""
    }
}
