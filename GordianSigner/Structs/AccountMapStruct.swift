//
//  AccountMapStruct.swift
//  GordianSigner
//
//  Created by Peter on 11/11/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

public struct AccountMapStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let accountMap:Data
    let dateAdded:Date
    let descriptor:String
    let birthblock:Int64?
    let complete:Bool
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as! String
        accountMap = dictionary["accountMap"] as! Data
        dateAdded = dictionary["dateAdded"] as! Date
        birthblock = dictionary["birthblock"] as? Int64
        descriptor = dictionary["descriptor"] as! String
        complete = dictionary["complete"] as! Bool
    }
    
    public var description: String {
        return ""
    }
}
