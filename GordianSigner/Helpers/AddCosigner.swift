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
        var segwitBip48Account = account
        var hack = "wsh(\(account)/0/*)"
        let dp = DescriptorParser()
        var ds = dp.descriptor(hack)
        var cosigner = [String:Any]()
        var shouldSign = false
        
        if let hdkey = try? HDKey(base58: ds.accountXprv) {
            guard let encryptedXprv = Encryption.encrypt(ds.accountXprv.utf8) else { return }
            cosigner["xprv"] = encryptedXprv
            shouldSign = true
            hack = hack.replacingOccurrences(of: ds.accountXprv, with: hdkey.xpub)
            segwitBip48Account = segwitBip48Account.replacingOccurrences(of: ds.accountXprv, with: hdkey.xpub)
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
        
        guard let ur = URHelper.cosignerToUrHdkey(segwitBip48Account, false), let lifehashFingerprint = URHelper.fingerprint(ur) else {
            completion((false, "Invalid Key", "Unsupported key, we only support Bitcoin mainnet/testnet hdkeys.", false, nil))
            return
        }
        
        cosigner["id"] = UUID()
        cosigner["label"] = "Cosigner"
        cosigner["bip48SegwitAccount"] = segwitBip48Account
        cosigner["dateAdded"] = Date()
        cosigner["fingerprint"] = ds.fingerprint
        cosigner["lifehash"] = lifehashFingerprint
        cosigner["shouldSign"] = shouldSign
        
        func save() {
            CoreDataService.saveEntity(dict: cosigner, entityName: .cosigner) { (success, errorDesc) in
                guard success else {
                    completion((false, "Cosigner not saved!", "Please let us know about this bug.", false, nil))
                    return
                }
                
                completion((true, "Cosigner imported ✓", nil, true, CosignerStruct(dictionary: cosigner)))
            }
        }
        
        func update(_ cosignerToUpdate: CosignerStruct) {
            CoreDataService.updateEntity(id: cosignerToUpdate.id, keyToUpdate: "xprv", newValue: cosigner["xprv"] as! Data, entityName: .cosigner) { (success, errorDescription) in
                guard success else {
                    completion((false, "Cosigner not updated!", "Please let us know about this bug.", false, nil))
                    return
                }
                
                CoreDataService.updateEntity(id: cosignerToUpdate.id, keyToUpdate: "shouldSign", newValue: true, entityName: .cosigner) { (success, errorDescription) in
                    guard success else {
                        completion((false, "Cosigner not updated!", "Please let us know about this bug.", false, nil))
                        return
                    }
                    
                    CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
                        guard let cosigners = cosigners else { return }
                        
                        for cosigner in cosigners {
                            let str = CosignerStruct(dictionary: cosigner)
                            if str.id == cosignerToUpdate.id {
                                completion((true, "Cosigner updated ✓", nil, false, str))
                            }
                        }
                    }
                }                
            }
        }
        
        CoreDataService.retrieveEntity(entityName: .cosigner) { (cosigners, errorDescription) in
            if let cosigners = cosigners, cosigners.count > 0 {
                var cosignerToUpdate:CosignerStruct?
                
                for (i, cosignerDict) in cosigners.enumerated() {
                    let cosignerStruct = CosignerStruct(dictionary: cosignerDict)
                    
                    if cosignerStruct.bip48SegwitAccount! == segwitBip48Account {
                        cosignerToUpdate = cosignerStruct
                    }
                    
                    if i + 1 == cosigners.count {
                        if cosignerToUpdate == nil {
                            save()
                        } else if cosigner["xprv"] != nil {
                            update(cosignerToUpdate!)
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
