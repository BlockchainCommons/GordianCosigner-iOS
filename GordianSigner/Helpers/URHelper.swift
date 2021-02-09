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
        let cbor = CBOR.encodeByteString(data.bytes).data//CBOR.byteString(data.bytes).encode(<#_#>).data
        
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
                                let (keydata, chaincode, origins, depth) = cborToCosigner(cbor: hdkeyCbor)
                                
                                guard let keyData = keydata, let chainCode = chaincode, let origin = origins else { return nil }
                                
                                path = origin
                                
                                guard let xpubCheck = URHelper.xpub(keyData, chainCode, "", xfp, depth) else { return nil }
                                
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
        guard let ur = try? URDecoder.decode(urString.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.map(dict) = decodedCbor else {
            return nil
        }
        
        var isMaster = false
        var keyData:String?
        var chainCode:String?
        var isPrivate = false
        var origins:String?
        var sourceXfp:String?
        var depth:String?
        var parentFingerprint:String?
        var network:String?
        
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
            case 5:
                guard case let CBOR.tagged(_, useInfoCbor) = value else { fallthrough }
                guard case let CBOR.map(map) = useInfoCbor else { fallthrough }
                
                network = URHelper.useInfo(map)
            case 6:
                guard case let CBOR.tagged(_, originCbor) = value else { fallthrough }
                guard case let CBOR.map(map) = originCbor else { fallthrough }
                
                (origins, depth, sourceXfp) = URHelper.origins(map)
            case 8:
                guard case let CBOR.unsignedInt(xfp) = value else { fallthrough }
                
                parentFingerprint = String(Int(xfp), radix: 16)
            default:
                break
            }
        }
        
        var extendedKey:String?
        var cosigner:String?
        
        guard let keydata = keyData, let chaincode = chainCode else { return nil }
        
        if !isPrivate && !isMaster {
            extendedKey = URHelper.xpub(keydata, chaincode, network ?? "main", parentFingerprint, depth)
        } else {
            extendedKey = URHelper.xprv(keydata, chaincode, network ?? "main", parentFingerprint, depth)
        }
        
        guard let key = extendedKey else { return nil }
        
        if isMaster {
            cosigner = Keys.bip48SegwitAccountXprv(key)
        } else {
            guard let origin = origins, let xfp = sourceXfp else { return nil }
            
            cosigner = "[\(xfp + "/" + origin)]\(key)"
        }
                
        return cosigner
    }
    
    static func xprv(_ keyData: String, _ chainCode: String, _ network: String?, _ xfp: String?, _ depth: String?) -> String? {
        var prefix = "0488ade4"//mainnet
        
        if network == "test" {
            prefix = "04358394"//testnet
        }
        
        // crypto-account omits use-info so need to go by our settings
        if network == "" {
            if Keys.coinType == "0" {
                prefix = "0488ade4"
            } else {
                prefix = "04358394"
            }
        }
        
        let parentXfp = xfp ?? "00000000"
        let childNumber = "80000002"
        
        var hexString = "\(prefix)\(depth ?? "00")\(parentXfp)\(childNumber)\(chainCode)\(keyData)"
        
        guard let data = Data(hexString: hexString) else { return nil }
        
        hexString += Encryption.checksum(data)
        
        guard let hexData = Data(hexString: hexString) else { return nil }
        
        return Base58.encode([UInt8](hexData))
    }
    
    static func xpub(_ keyData: String, _ chainCode: String, _ network: String, _ xfp: String?, _ depth: String?) -> String? {
        var prefix = "0488b21e"//mainnet
        
        if network == "test" {
            prefix = "043587cf"//testnet
        }
        
        // crypto-account omits use-info so need to go by our settings
        if network == "" {
            if Keys.coinType == "0" {
                prefix = "0488b21e"
            } else {
                prefix = "043587cf"
            }
        }
        
        let sourceXfp = xfp ?? "00000000"
        let childNumber = "80000002"//hardened 2' derivation component
        
        var hexString = "\(prefix)\(depth ?? "00")\(sourceXfp)\(childNumber)\(chainCode)\(keyData)"
        
        guard let data = Data(hexString: hexString) else { return nil }
        
        hexString += Encryption.checksum(data)
        
        guard let hexData = Data(hexString: hexString) else { return nil }
        
        return Base58.encode([UInt8](hexData))
    }
    
    static func cborToCosigner(cbor: CBOR) -> (keyData: String?, chainCode: String?, origins: String?, depth: String?) {
        guard case let CBOR.map(dict) = cbor else { return (nil, nil, nil, nil) }
        
        var keyData:String?
        var chainCode:String?
        var origins:String?
        var depth:String?
        
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
                let (originsCheck, depthCheck, _) = URHelper.origins(map)
                origins = originsCheck
                depth = depthCheck
                
            default:
                break
            }
        }
        return (keyData, chainCode, origins, depth)
    }
    
    private static func origins(_ map: [CBOR : CBOR]) -> (path: String?, depth: String?, sourceXfp: String?) {
        var path = ""
        var depthString = "00"
        var sourceXfp = "00000000"
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
            case 2:
                if case let CBOR.unsignedInt(xfp) = v {
                    sourceXfp = String(format: "%08x", xfp)
                }
            case 3:
                if case let CBOR.unsignedInt(depth) = v {
                    if depth < 10 {
                        depthString = String(format: "%02d", depth)
                    } else {
                        depthString = "\(depth)"
                    }
                }
            default:
                break
            }
        }
        
        return (path, depthString, sourceXfp)
    }
    
    private static func useInfo(_ map: [CBOR : CBOR]) -> String? {
        var network = ""
        for (k, v) in map {
            switch k {
            case 1:
                // type
                switch v {
                case CBOR.unsignedInt(0):
                    print("btc")
                default:
                    break
                }
            case 2:
                // network
                switch v {
                case CBOR.unsignedInt(0):
                    network = "main"
                case CBOR.unsignedInt(1):
                    network = "test"
                default:
                    break
                }
            default:
                break
            }
        }
        
        return network
    }
    
    static func cosignerToUr(_ cosigner: String, _ isPrivate: Bool) -> String? {
        let descriptorParser = DescriptorParser()
        let descriptor = "wsh(\(cosigner))"
        let descriptorStruct = descriptorParser.descriptor(descriptor)
        var key = descriptorStruct.accountXpub
        
        if isPrivate {
            key = descriptorStruct.accountXprv
        }
        
        /// Decodes our original extended key to base58 data.
        let b58 = Base58.decode(key)
        let b58Data = Data(b58)
        let depth = b58Data.subdata(in: Range(4...4))
        let parentFingerprint = b58Data.subdata(in: Range(5...8))
        let childIndex = b58Data.subdata(in: Range(9...12))
        guard childIndex.hexString == "80000002" else { return nil }
        let chaincode = b58Data.subdata(in: Range(13...44))
        let keydata = b58Data.subdata(in: Range(45...77))
        
        var cointype:UInt64 = 1
        if Keys.coinType == "0" {
            cointype = 0
        }
        
        let originsWrapper:CBOR = .map([
            .unsignedInt(1) : .array([.unsignedInt(48), true, .unsignedInt(cointype), true, .unsignedInt(0), true, .unsignedInt(2), true]),// derivation
            .unsignedInt(2) : .unsignedInt(UInt64(descriptorStruct.fingerprint, radix: 16) ?? 0),// source xfp
            .unsignedInt(3) : .unsignedInt(UInt64(depth.hexString) ?? 0)// depth
        ])
        
        let useInfoWrapper:CBOR = .map([
            .unsignedInt(2) : .unsignedInt(cointype)
        ])
        
        guard let hexValue = UInt64(parentFingerprint.hexString, radix: 16) else { return nil }
        
        let hdKeyWrapper:CBOR = .map([
            .unsignedInt(1) : .boolean(false), //isMaster
            .unsignedInt(2) : .boolean(isPrivate), //isPrivate
            .unsignedInt(3) : .byteString([UInt8](keydata)), //keyData bytestring
            .unsignedInt(4) : .byteString([UInt8](chaincode)), //chainCode bytestring
            .unsignedInt(5) : .tagged(CBOR.Tag(rawValue: 305), useInfoWrapper), //use-info 1 = testnet-btc
            .unsignedInt(6) : .tagged(CBOR.Tag(rawValue: 304), originsWrapper),
            .unsignedInt(8) : .unsignedInt(hexValue)
        ])
        
        guard let rawUr = try? UR(type: "crypto-hdkey", cbor: hdKeyWrapper) else { return nil }
        
        return UREncoder.encode(rawUr)
    }
    
    static func fingerprint(_ hdKey: String) -> Data? {
        var result: [CBOR] = []
        
        guard let ur = try? URDecoder.decode(hdKey.condenseWhitespace()),
              let decodedCbor = try? CBOR.decode(ur.cbor.bytes),
              case let CBOR.map(dict) = decodedCbor else {
            return nil
        }
        
        var keyData:Data!
        var chainCode:Data?
        var chain:UInt = 0
        
        for (key, value) in dict {
            switch key {
            case 3:
                guard case let CBOR.byteString(bs) = value else { fallthrough }
                
                keyData = Data(bs)
            case 4:
                guard case let CBOR.byteString(bs) = value else { fallthrough }
                
                chainCode = Data(bs)
            case 5:
                guard case let CBOR.tagged(_, useInfoCbor) = value else { fallthrough }
                guard case let CBOR.map(map) = useInfoCbor else { fallthrough }
                
                let network = URHelper.useInfo(map)
                
                if network == "main" {
                    chain = 0
                } else if network == "test" {
                    chain = 1
                }
            default:
                break
            }
        }
        
        result.append(CBOR.byteString(keyData.bytes))
        
        if let chainCode = chainCode {
            result.append(CBOR.byteString(chainCode.bytes))
        } else {
            result.append(CBOR.null)
        }
        
        result.append(CBOR.unsignedInt(UInt64(0)))
        result.append(CBOR.unsignedInt(UInt64(chain)))
        
        return Data(result.encode())
    }
    
}
