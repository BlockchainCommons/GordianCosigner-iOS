//
//  Encryption.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import CryptoKit

enum Encryption {
    
    static func decryptedSeeds() -> [String]? {
        guard let encryptedSeeds = KeyChain.seeds(), encryptedSeeds.count > 0 else { return nil }
        
        var decryptedSeeds:[String] = []
        
        for seed in encryptedSeeds {
            guard let decryptedSeed = Encryption.decryptData(dataToDecrypt: seed),
                let words = String(data: decryptedSeed, encoding: .utf8) else { return nil }
            
            decryptedSeeds.append(words)
        }
        
        return decryptedSeeds
    }
    
    static func privateKey() -> Data {
        return P256.Signing.PrivateKey().rawRepresentation
    }
    
    static func encryptData(dataToEncrypt: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey") else { return nil }
                
        return try? ChaChaPoly.seal(dataToEncrypt, using: SymmetricKey(data: key)).combined
    }
    
    static func decryptData(dataToDecrypt: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey"),
            let box = try? ChaChaPoly.SealedBox.init(combined: dataToDecrypt) else { return nil }
                
        return try? ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }
    
}
