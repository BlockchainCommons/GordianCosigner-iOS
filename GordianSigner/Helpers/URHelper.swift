//
//  URHelper.swift
//  GordianSigner
//
//  Created by Peter on 10/7/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import URKit

enum URHelper {

    static func psbtUr(_ data: Data) -> UR? {
        let cbor = CBOR.byteString(data.bytes).encode().data
        
        return try? UR(type: "crypto-psbt", cbor: cbor)
    }
    
    static func psbtUrToBase64Text(_ ur: UR) -> String? {
        guard let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
            case let CBOR.byteString(bytes) = decodedCbor else {
                return nil
        }
        
        return Data(bytes).base64EncodedString()
    }
    
    static func accountUr(_ urString: String) -> String? {
        var xfp = ""
        var xpub = ""
        var path = ""
        
        guard let ur = try? URDecoder.decode(urString) else { return nil }
        guard let decodedCbor = try? CBOR.decode(ur.cbor.bytes) else { return nil }
        guard case let CBOR.map(dict) = decodedCbor else { return nil }
        
        for (key, value) in dict {
            switch key {
            case 1:
                guard case let CBOR.unsignedInt(fingerprint) = value else { fallthrough }
                let hex = String(Int(fingerprint), radix: 16)
                xfp = "[\(hex)/"
            case 2:
                guard case let CBOR.array(accounts) = value else { fallthrough }
                
                for elem in accounts {
                    if case let CBOR.tagged(tag, rawCbor) = elem {
                        if tag.rawValue == 401 {
                            if case let CBOR.tagged(_, hdkeyCbor) = rawCbor {
                                let (keydata, chaincode, origins) = urToHdkey(cbor: hdkeyCbor)
                                guard let keyData = keydata, let chainCode = chaincode, let origin = origins else { return nil }
                                path = origin
                                let prefix = "0488b21e"//mainnet "043587cf"//testnet
                                var base58String = "\(prefix)000000000000000000\(chainCode)\(keyData)"
                                
                                if let data = Data(base64Encoded: base58String) {
                                    let checksum = Encryption.checksum(Data(data))
                                    base58String += checksum
                                    if let rawData = Data(base64Encoded: base58String) {
                                        xpub = Base58.encode([UInt8](rawData))
                                    }
                                }
                            }
                        }
                    }
                }

            default:
                break
            }
        }
        
        guard xfp != "", path != "", xpub != "" else { return nil }
                
        return xfp + path + "]" + xpub
    }
    
    static func urToHdkey(cbor: CBOR) -> (keyData: String?, chainCode: String?, origins: String?) {
        guard case let CBOR.map(dict) = cbor else { return (nil, nil, nil) }
        
        var keyData:String?
        var chainCode:String?
        var origins:String?
        
        for (key, value) in dict {
            switch key {
            case 3:
                guard case let CBOR.byteString(bs) = value else { fallthrough }
                keyData = Data(bs).hexString
            case 4:
                guard case let CBOR.byteString(bs) = value else { fallthrough }
                chainCode = Data(bs).hexString
            case 6:
                guard case let CBOR.tagged(_, originCbor) = value else { fallthrough }
                guard case let CBOR.map(map) = originCbor else { fallthrough }
                
                for (k, v) in map {
                    switch k {
                    case 1:
                        if case let CBOR.array(originsArray) = v {
                            var path = ""
                            
                            for (i, elem) in originsArray.enumerated() {
                                
                                if case let CBOR.unsignedInt(comp) = elem {
                                    path += "\(comp)"
                                }
                                
                                if case let CBOR.boolean(isHardened) = elem {
                                    
                                    if isHardened {
                                        
                                        if i < originsArray.count - 1 {
                                            path += "h/"
                                        } else {
                                            path += "h"
                                        }
                                        
                                    } else {
                                        
                                        if i < originsArray.count - 1 {
                                            path += "/"
                                        }
                                    }
                                }
                                
                                if i + 1 == originsArray.count {
                                    origins = path
                                }
                            }
                        }
                        
                    default:
                        print("nothing")
                    }
                }
                
            default:
                break
            }
        }
        return (keyData, chainCode, origins)
    }
    
}
