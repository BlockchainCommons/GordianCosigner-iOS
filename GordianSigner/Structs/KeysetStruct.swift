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
    let bip44Account:String?
    let bip45Account:String?
    let bip48LegacyAccount:String?
    let bip48NestedAccount:String?
    let bip48SegwitAccount:String?
    let bip49Account:String?
    let bip84Account:String?
    let dateAdded:Date
    let dateShared:Date?
    let sharedWith:UUID?
    let fingerprint:String
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as! String
        bip44Account = dictionary["bip44Account"] as? String
        bip45Account = dictionary["bip45Account"] as? String
        bip48LegacyAccount = dictionary["bip48LegacyAccount"] as? String
        bip48NestedAccount = dictionary["bip48NestedAccount"] as? String
        bip48SegwitAccount = dictionary["bip48SegwitAccount"] as? String
        bip49Account = dictionary["bip49Account"] as? String
        bip84Account = dictionary["bip84Account"] as? String
        dateAdded = dictionary["dateAdded"] as! Date
        dateShared = dictionary["dateShared"] as? Date
        sharedWith = dictionary["sharedWith"] as? UUID
        fingerprint = dictionary["fingerprint"] as? String ?? "00000000"
    }
    
    public var description: String {
        return ""
    }
}
