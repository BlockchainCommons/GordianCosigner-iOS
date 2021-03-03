//
//  AddCosigner.swift
//  GordianSigner
//
//  Created by Peter Denton on 3/3/21.
//  Copyright © 2021 Blockchain Commons. All rights reserved.
//

import Foundation
import LibWally

enum AddCosigner {
    
    static func add(_ account: String, completion: @escaping (((success: Bool, message: String, errorDesc: String?, savedNew: Bool, cosignerStruct: CosignerStruct?)) -> Void)) {
        var segwitBip84Account = account
        var hack = "wsh(\(account)/0/*)"
        let dp = DescriptorParser()
        var ds = dp.descriptor(hack)
        var cosigner = [String:Any]()
        
        if let hdkey = try? HDKey(base58: ds.accountXprv) {
            guard let encryptedXprv = Encryption.encrypt(ds.accountXprv.utf8) else { return }
            cosigner["xprv"] = encryptedXprv
            hack = hack.replacingOccurrences(of: ds.accountXprv, with: hdkey.xpub)
            segwitBip84Account = segwitBip84Account.replacingOccurrences(of: ds.accountXprv, with: hdkey.xpub)
            ds = dp.descriptor(hack)
        }
        
        guard let _ = try? HDKey(base58: ds.accountXpub) else {
            completion((false, "Invalid Key", "That does not appear to be a valid Cosigner, please let us know about this issue on Github.", false, nil))
            return
        }
        
        guard account.contains("/48h/\(Keys.coinType)h/0h/2h") || account.contains("/48'/\(Keys.coinType)'/0'/2'") else {
            completion((false, "Derivation not supported", "Gordian Cosigner currently only supports the m/48h/\(Keys.coinType)h/0h/2h key origin.", false, nil))
            return
        }
        
        guard let ur = URHelper.cosignerToUr(segwitBip84Account, false), let lifehashFingerprint = URHelper.fingerprint(ur) else {
            completion((false, "Invalid Key", "Unsupported key, we only support Bitcoin mainnet/testnet hdkeys.", false, nil))
            return
        }
        
        cosigner["id"] = UUID()
        cosigner["label"] = "Cosigner"
        cosigner["bip48SegwitAccount"] = segwitBip84Account
        cosigner["dateAdded"] = Date()
        cosigner["fingerprint"] = ds.fingerprint
        cosigner["lifehash"] = lifehashFingerprint
        
        func save() {
            CoreDataService.saveEntity(dict: cosigner, entityName: .cosigner) { (success, errorDesc) in
                guard success else {
                    completion((false, "Cosigner not saved!", "Please let us know about this bug.", false, nil))
                    return
                }
                
                completion((true, "Cosigner imported ✓", nil, true, CosignerStruct(dictionary: cosigner)))
            }
        }
        
        func update(_ id: UUID) {
            CoreDataService.updateEntity(id: id, keyToUpdate: "xprv", newValue: cosigner["xprv"] as! Data, entityName: .cosigner) { (success, errorDescription) in
                guard success else {
                    completion((false, "Cosigner not updated!", "Please let us know about this bug.", false, nil))
                    return
                }
                
                completion((true, "Cosigner updated ✓", nil, false, CosignerStruct(dictionary: cosigner)))
            }
        }
        
        CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
            if let cosigners = cosigners, cosigners.count > 0 {
                var idToUpdate:UUID?
                for (i, cosignerDict) in cosigners.enumerated() {
                    let cosignerStruct = CosignerStruct(dictionary: cosignerDict)
                    
                    if cosignerStruct.bip48SegwitAccount == segwitBip84Account {
                        //update existing
                        idToUpdate = cosignerStruct.id
                    }
                    
                    if i + 1 == cosigners.count {
                        if idToUpdate == nil {
                            save()
                        } else if cosigner["xprv"] != nil {
                            update(idToUpdate!)
                        } else {
                            completion((false, "", "That Cosigner already exists.", false, nil))
                        }
                    }
                }
            } else {
                save()
            }
        }
    }
}
