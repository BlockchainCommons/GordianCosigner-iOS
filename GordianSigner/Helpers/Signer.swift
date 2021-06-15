//
//  Signer.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import LibWally

class PSBTSigner {
    
    class func sign(_ psbt: String, completion: @escaping ((psbt: PSBT?, signedFor: [String]?, errorMessage: String?)) -> Void) {
        var xprvsToSignWith = [HDKey]()
        var masterKeysToSignWith = [HDKey]()
        var psbtToSign:PSBT!
        var signedFor = [String]()
        var signableKeys = [String]()
        
        func reset() {
            signableKeys.removeAll()
            masterKeysToSignWith.removeAll()
            xprvsToSignWith.removeAll()
        }
        
        func sign() {
            let uniqueSigners = Array(Set(signableKeys))
            
            guard uniqueSigners.count > 0 else {
                reset()
                completion((nil, nil, "Looks like none of your Cosigners can sign this psbt."))
                return
            }
            
            for (s, signer) in uniqueSigners.enumerated() {
                guard let signingKey = try? Key(wif: signer, network: Keys.chain) else {
                    reset()
                    completion((nil, nil, "There was an error deriving your private key for signing."))
                    return
                }
                signedFor.append(signingKey.pubKey.data.hexString)
                psbtToSign = try? psbtToSign.signed(with: signingKey)
                if s + 1 == uniqueSigners.count {
                    reset()
                    completion((psbtToSign, signedFor, nil))
                }
            }
        }
        
        func attemptToSignWithMasterKeys() {
            if masterKeysToSignWith.count > 0 {
                for (i, key) in masterKeysToSignWith.enumerated() {
                    let inputs = psbtToSign.inputs
                    
                    for (x, input) in inputs.enumerated() {
                        /// Create an array of child keys that we know can sign our inputs.
                        if let origins = input.origins {
                            for origin in origins {
                                if let childKey = try? key.derive(using: origin.value.path) {
                                    if let privKey = childKey.privKey {
                                        if childKey.pubKey == origin.key {
                                            signableKeys.append(privKey.wif)
                                        }
                                    }
                                }
                            }
                        }
                        
                        /// Once the above loops complete we remove any duplicate signing keys from the array then sign the psbt with each unique key.
                        if i + 1 == masterKeysToSignWith.count && x + 1 == inputs.count {
                            sign()
                        }
                    }
                }
            } else {
                sign()
            }
        }
        
        func attemptToSignWithAccountXprvs() {
            if xprvsToSignWith.count > 0 {
                for (i, key) in xprvsToSignWith.enumerated() {
                    let inputs = psbtToSign.inputs
                    
                    for (x, input) in inputs.enumerated() {
                        /// Create an array of child keys that we know can sign our inputs.
                        if let origins = input.origins {
                            for origin in origins {
                                if let path = try? origin.value.path.chop(depth: 4) {
                                    if let childKey = try? key.derive(using: path) {
                                        if let privKey = childKey.privKey {
                                            if childKey.pubKey == origin.key {
                                                signableKeys.append(privKey.wif)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        /// Once the above loops complete we remove any duplicate signing keys from the array then sign the psbt with each unique key.
                        if i + 1 == xprvsToSignWith.count && x + 1 == inputs.count {
                            attemptToSignWithMasterKeys()
                        }
                    }
                }
            } else {
                attemptToSignWithMasterKeys()
            }
        }
        
        /// Fetch keys to sign with
        func getXprvs() {
            CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
                guard let cosigners = cosigners, cosigners.count > 0 else {
                    completion((nil, nil, "Looks like you do not have any cosigners added yet. Go the the Cosigners tab and tap the + button to add one."))
                    return
                }
                
                for (i, cosigner) in cosigners.enumerated() {
                    let cosignerStruct = CosignerStruct(dictionary: cosigner)
                    
                    if let encryptedXprv = cosignerStruct.xprv {
                        guard let decryptedXprv = Encryption.decrypt(encryptedXprv) else {
                            reset()
                            completion((nil, nil, "There was an error decrypting your account xprv."))
                            return
                        }
                                                
                        guard let hdkey = try? HDKey(base58: decryptedXprv.utf8) else {
                            reset()
                            completion((nil, nil, "There was an error deriving your account xprv."))
                            return
                        }
                        
                        xprvsToSignWith.append(hdkey)
                    }
                    
                    if let encryptedMasterKey = cosignerStruct.masterKey {
                        guard let decryptedMasterKey = Encryption.decrypt(encryptedMasterKey) else {
                            reset()
                            completion((nil, nil, "There was an error decrypting your master key."))
                            return
                        }
                        
                        guard let hdkey = try? HDKey(base58: decryptedMasterKey.utf8) else {
                            reset()
                            completion((nil, nil, "There was an error deriving your master key."))
                            return
                        }
                        
                        masterKeysToSignWith.append(hdkey)
                    }
                    
                    if i + 1 == cosigners.count {
                        attemptToSignWithAccountXprvs()
                    }
                }
            }
        }
        
        do {
            psbtToSign = try PSBT(psbt: psbt, network: Keys.chain)
            
            if psbtToSign.isComplete {
                completion((psbtToSign, nil, nil))
            } else {
                getXprvs()
            }
            
        } catch {
             completion((nil, nil, "Error converting that psbt."))
        }
    }
}

