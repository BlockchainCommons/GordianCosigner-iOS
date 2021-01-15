//
//  AccountMapStruct.swift
//  GordianSigner
//
//  Created by Peter on 11/11/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

public struct AccountStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let map:Data
    let dateAdded:Date
    let descriptor:String
    let birthblock:Int64?
    let complete:Bool
    let lifehash:Data?
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as! String
        map = dictionary["map"] as! Data
        dateAdded = dictionary["dateAdded"] as! Date
        birthblock = dictionary["birthblock"] as? Int64
        descriptor = dictionary["descriptor"] as! String
        complete = dictionary["complete"] as! Bool
        lifehash = dictionary["lifehash"] as? Data
    }
    
    public var description: String {
        return ""
    }
}
