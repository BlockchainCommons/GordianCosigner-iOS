//
//  LifeHash.swift
//  GordianSigner
//
//  Created by Peter on 11/11/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import UIKit
import LifeHash

enum LifeHash {
    
    static func image(_ input: String) -> UIImage {
        let arr = input.split(separator: "#")
        var bare = ""
        
        if arr.count > 0 {
            bare = "\(arr[0])".replacingOccurrences(of: "'", with: "h")
        } else {
            bare = input.replacingOccurrences(of: "'", with: "h")
        }
        
        return LifeHashGenerator.generateSync(bare)
    }
    
    static func hash(_ input: Data) -> Data? {
        return LifeHashGenerator.generateSync(input).pngData()
    }
    
    static func hash(_ input: String) -> Data? {
        return LifeHashGenerator.generateSync(input).pngData()
    }
    
    static func image(_ input: Data) -> UIImage? {
       return LifeHashGenerator.generateSync(input)
    }
}
