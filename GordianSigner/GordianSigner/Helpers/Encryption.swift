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
            guard let decryptedSeed = Encryption.decrypt(seed),
                let words = String(data: decryptedSeed, encoding: .utf8) else { return nil }
            
            decryptedSeeds.append(words)
        }
        
        return decryptedSeeds
    }
    
    static func privateKey() -> Data {
        return P256.Signing.PrivateKey().rawRepresentation
    }
    
    static func encrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey") else { return nil }
                
        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
    }
    
    static func decrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey"),
            let box = try? ChaChaPoly.SealedBox.init(combined: data) else { return nil }
                
        return try? ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }
    
}
