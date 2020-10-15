//
//  Signer.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import LibWally

class Signer {
    
    class func sign(_ psbt: String, completion: @escaping ((psbt: String?, errorMessage: String?)) -> Void) {
        var seedsToSignWith = [String]()
        var xprvsToSignWith = [HDKey]()
        var psbtToSign:PSBT!
        
        func reset() {
            seedsToSignWith.removeAll()
            xprvsToSignWith.removeAll()
            psbtToSign = nil
        }
        
        func attemptToSignLocally() {
            /// Need to ensure similiar seeds do not sign mutliple times. This can happen if a user adds the same seed multiple times.
            var xprvStrings = [String]()
            
            for xprv in xprvsToSignWith {
                xprvStrings.append(xprv.description)
            }
            
            xprvsToSignWith.removeAll()
            let uniqueXprvs = Array(Set(xprvStrings))
            
            for uniqueXprv in uniqueXprvs {
                if let xprv = HDKey(uniqueXprv) {
                    xprvsToSignWith.append(xprv)
                }
            }
            
            guard xprvsToSignWith.count > 0  else { return }
            var signableKeys = [String]()
            
            for (i, key) in xprvsToSignWith.enumerated() {
                let inputs = psbtToSign.inputs
                
                for (x, input) in inputs.enumerated() {
                    /// Create an array of child keys that we know can sign our inputs.
                    if let origins: [PubKey : KeyOrigin] = input.canSign(key) {
                        for origin in origins {
                            if let childKey = try? key.derive(origin.value.path) {
                                if let privKey = childKey.privKey {
                                    signableKeys.append(privKey.wif)
                                }
                            }
                        }
                    }
                    
                    /// Once the above loops complete we remove an duplicate signing keys from the array then sign the psbt with each unique key.
                    if i + 1 == xprvsToSignWith.count && x + 1 == inputs.count {
                        let uniqueSigners = Array(Set(signableKeys))
                        
                        guard uniqueSigners.count > 0 else {
                            completion((nil, "Looks like none of your signers can sign this psbt, ensure you added the signer and its optional passphrase correctly."))
                            return
                        }
                        
                        for (s, signer) in uniqueSigners.enumerated() {
                            guard let signingKey = Key(signer, .testnet) else { return }
                            
                            psbtToSign.sign(signingKey)
                            /// Once we completed the signing loop we finalize with our node.
                            if s + 1 == uniqueSigners.count {
                                completion((psbtToSign.description, nil))
                            }
                        }
                    }
                }
            }
        }
        
        /// Fetch keys to sign with
        func getKeysToSignWith() {
            xprvsToSignWith.removeAll()
            
            for (i, words) in seedsToSignWith.enumerated() {
                guard let masterKey = Keys.masterKey(words, ""),
                    let hdkey = HDKey(masterKey) else { return }
                
                xprvsToSignWith.append(hdkey)
                
                if i + 1 == seedsToSignWith.count {
                    attemptToSignLocally()
                }
            }
        }
        
        /// Fetch wallets on the same network
        func getSeeds() {
            seedsToSignWith.removeAll()
            
            guard let seeds = Encryption.decryptedSeeds(), seeds.count > 0 else {
                completion((nil, "Looks like you do not have any signers added yet. Tap the signer button then + to add signers."))
                return
            }
            
            for (i, seed) in seeds.enumerated() {
                seedsToSignWith.append(seed)
                
                if i + 1 == seeds.count {
                    getKeysToSignWith()
                }
            }
        }
        
        do {
            psbtToSign = try PSBT(psbt, .testnet)
            
            if psbtToSign.complete {
                completion((psbt, nil))
            } else {
                getSeeds()
            }
            
        } catch {
            
            completion((nil, "Error converting that psbt"))
        }
    }
}

