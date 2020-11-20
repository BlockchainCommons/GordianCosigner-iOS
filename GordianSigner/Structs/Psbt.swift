//
//  Psbt.swift
//  GordianSigner
//
//  Created by Peter on 11/17/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

public struct PsbtStruct: CustomStringConvertible {
    
    let id:UUID
    let label:String
    let psbt:Data
    let dateAdded:Date
    let dateSigned:Date?
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as! UUID
        label = dictionary["label"] as! String
        psbt = dictionary["psbt"] as! Data
        dateAdded = dictionary["dateAdded"] as! Date
        dateSigned = dictionary["dateSigned"] as? Date
    }
    
    public var description: String {
        return ""
    }
}
