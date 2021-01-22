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
    
    static func accountUrToCosigner(_ urString: String) -> String? {
        var xfp = ""
        var xpub = ""
        var path = ""
        
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.map(dict) = decodedCbor else {
            
            return nil
        }
        
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
                                let (keydata, chaincode, origins) = cborToCosigner(cbor: hdkeyCbor)
                                
                                guard let keyData = keydata, let chainCode = chaincode, let origin = origins else { return nil }
                                
                                path = origin
                                
                                guard let xpubCheck = URHelper.xpub(keyData, chainCode) else { return nil }
                                
                                xpub = xpubCheck
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
    
    static func urHdkeyToCosigner(_ urString: String) -> String? {
        guard let ur = try? URDecoder.decode(urString),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.map(dict) = decodedCbor else {
            return nil
        }
        
        var isMaster = false
        var keyData:String?
        var chainCode:String?
        var isPrivate = false
        var origins:String?
        var fingerprint:String?
        
        for (key, value) in dict {
            switch key {
            case 1:
                guard case let CBOR.boolean(b) = value else { fallthrough }
                
                isMaster = b
            case 2:
                guard case let CBOR.boolean(b) = value else { fallthrough }
                
                isPrivate = b
            case 3:
                guard case let CBOR.byteString(bs) = value else { fallthrough }
                
                keyData = Data(bs).hexString
            case 4:
                guard case let CBOR.byteString(bs) = value else { fallthrough }
                
                chainCode = Data(bs).hexString
            case 6:
                guard case let CBOR.tagged(_, originCbor) = value else { fallthrough }
                guard case let CBOR.map(map) = originCbor else { fallthrough }
                
                origins = URHelper.origins(map)
                
            case 8:
                guard case let CBOR.unsignedInt(xfp) = value else { fallthrough }
                
                fingerprint = String(Int(xfp), radix: 16)
            default:
                break
            }
        }
        
        var extendedKey:String?
        var cosigner:String?
        
        guard let keydata = keyData, let chaincode = chainCode else { return nil }
        
        if !isPrivate && !isMaster {
            extendedKey = URHelper.xpub(keydata, chaincode)
        } else {
            extendedKey = URHelper.xprv(keydata, chaincode)
        }
        
        guard let key = extendedKey else { return nil }
        
        if isMaster {
            cosigner = Keys.bip48SegwitAccountXprv(key)
        } else {
            guard let origin = origins, let xfp = fingerprint else { return nil }
            
            cosigner = "[\(xfp + "/" + origin)]\(key)"
        }
                
        return cosigner
    }
    
    static func xprv(_ keyData: String, _ chainCode: String) -> String? {
        var prefix = "0488ade4"//mainnet
        
        if Keys.coinType == "1" {
            prefix = "04358394"//testnet
        }
        
        var hexString = "\(prefix)000000000000000000\(chainCode)\(keyData)"
        
        guard let data = Data(hexString: hexString) else { return nil }
        
        hexString += Encryption.checksum(data)
        
        guard let hexData = Data(hexString: hexString) else { return nil }
        
        return Base58.encode([UInt8](hexData))
    }
    
    static func xpub(_ keyData: String, _ chainCode: String) -> String? {
        var prefix = "0488b21e"//mainnet
        
        if Keys.coinType == "1" {
            prefix = "043587cf"//testnet
        }
        
        var hexString = "\(prefix)000000000000000000\(chainCode)\(keyData)"
        
        guard let data = Data(hexString: hexString) else { return nil }
        
        hexString += Encryption.checksum(data)
        
        guard let hexData = Data(hexString: hexString) else { return nil }
        
        return Base58.encode([UInt8](hexData))
    }
    
    static func cborToCosigner(cbor: CBOR) -> (keyData: String?, chainCode: String?, origins: String?) {
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
                guard let originsCheck = URHelper.origins(map) else { fallthrough }
                origins = originsCheck
                
            default:
                break
            }
        }
        return (keyData, chainCode, origins)
    }
    
    private static func origins(_ map: [CBOR : CBOR]) -> String? {
        var path = ""
        for (k, v) in map {
            switch k {
            case 1:
                if case let CBOR.array(originsArray) = v {
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
                    }
                }
            default:
                break
            }
        }
        
        return path
    }
    
//    static func account(_ account: String) -> UR? {
//        //[73756c7f/48h/0h/0h/2h]xpub6E3pgkahcxomzJRVmEQb9RjdB4Xx4tjRL6mmmfNzpgvFjL94jTQSHGqpfeWwE4wvhFbomye5mMQNrDiAdgEnfzcGWVgbsAiN4W86bKfpihD
//    }
//    
//    static func keysetToUr(keyset: String) -> String? {
//        let descriptorParser = DescriptorParser()
//        let descriptor = "wsh(\(keyset))"
//        let descriptorStruct = descriptorParser.descriptor(descriptor)
//        let xfp = Data(value: descriptorStruct.fingerprint)
//        let key = descriptorStruct.accountXpub
//        
//        let hdKeyWrapper:CBOR = .map([
//            .unsignedInt(3) : .byteString(<#T##[UInt8]#>), //keyData bytestring
//            .unsignedInt(4) : .byteString(<#T##[UInt8]#>) //chainCode bytestring
//            .unsignedInt(6) : .byteString(<#T##[UInt8]#>) //chainCode bytestring
//        ])
//        
//        let arrayWrapper:CBOR = .array([
//            .tagged(.init(rawValue: 401), hdKeyWrapper)
//        ])
//        
//        let wrapper:CBOR = .map([
//            .unsignedInt(1) : .byteString(xfp.bytes),
//            .unsignedInt(2) : .array([arrayWrapper])
//        ])
//        //let wrapper:CBOR = .tagged(.init(rawValue: 309), .byteString(data.bytes))
//        let cbor = Data(wrapper.encode())
//        do {
//            let rawUr = try UR(type: "crypto-account", cbor: cbor)
//            return UREncoder.encode(rawUr)
//        } catch {
//            return nil
//        }
//    }
    
}
