//
//  URHelper.swift
//  GordianSigner
//
//  Created by Peter on 10/7/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import URKit
import LibWally

enum URHelper {
    
    static func mnemonicToCryptoSeed(_ words: String) -> String? {
        guard let entropy = try? BIP39Mnemonic(words: words).entropy else { return nil }
        
        return URHelper.entropyToUr(data: entropy.data)
    }
    
    static func cryptoSeedToMnemonic(cryptoSeed: String) -> String? {
        guard let data = URHelper.urToEntropy(urString: cryptoSeed).data, let mnemonic = try? BIP39Mnemonic(entropy: BIP39Mnemonic.Entropy(data)) else { return nil }
        
        return mnemonic.words.joined(separator: " ")
    }
    
    // crypto-seed > mnemonic
    static func urToEntropy(urString: String) -> (data: Data?, birthdate: UInt64?) {
        do {
            let ur = try URDecoder.decode(urString)
            let decodedCbor = try CBOR.decode(ur.cbor.bytes)
            guard case let CBOR.map(dict) = decodedCbor! else { return (nil, nil) }
            var data:Data?
            var birthdate:UInt64?
            for (key, value) in dict {
                switch key {
                case 1:
                    guard case let CBOR.byteString(byteString) = value else { fallthrough }
                    data = Data(byteString)
                case 2:
                    guard case let CBOR.unsignedInt(n) = value else { fallthrough }
                    birthdate = n
                default:
                    break
                }
            }
            return (data, birthdate)
        } catch {
            return (nil, nil)
        }
    }
    
    // mnemonic > crypto-seed
    static func entropyToUr(data: Data) -> String? {
        let wrapper:CBOR = .map([
            .unsignedInt(1) : .byteString(data.bytes),
        ])
        let cbor = Data(wrapper.cborEncode())
        do {
            let rawUr = try UR(type: "crypto-seed", cbor: cbor)
            return UREncoder.encode(rawUr)
        } catch {
            return nil
        }
    }

    static func psbtUr(_ data: Data) -> UR? {
        let cbor = CBOR.encodeByteString(data.bytes).data
        
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
                let (type, net) = URHelper.useInfo(map)
                network = net
                
                if type != "btc" {
                    return nil
                }
            case 6:
                guard case let CBOR.tagged(_, originCbor) = value else { fallthrough }
                guard case let CBOR.map(map) = originCbor else { fallthrough }
                
                (origins, depth, sourceXfp) = URHelper.origins(map)
            case 8:
                guard case let CBOR.unsignedInt(xfp) = value else { fallthrough }
                
                parentFingerprint = String(format: "%08x", xfp)
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
    
    private static func useInfo(_ map: [CBOR : CBOR]) -> (type: String?, network: String?) {
        var network = "main"
        var type = "btc"
        for (k, v) in map {
            switch k {
            case 1:
                // type
                switch v {
                case CBOR.unsignedInt(0):
                    type = "btc"
                case CBOR.unsignedInt(145):
                    type = "bcash"
                default:
                    type = "?"
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
        
        return (type, network)
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
        
        var originsArray:[OrderedMapEntry] = []
        originsArray.append(.init(key: 1, value: .array([.unsignedInt(48), true, .unsignedInt(cointype), true, .unsignedInt(0), true, .unsignedInt(2), true])))
        originsArray.append(.init(key: 2, value: .unsignedInt(UInt64(descriptorStruct.fingerprint, radix: 16) ?? 0)))
        originsArray.append(.init(key: 3, value: .unsignedInt(UInt64(depth.hexString) ?? 0)))
        let originsWrapper = CBOR.orderedMap(originsArray)
        
        let useInfoWrapper:CBOR = .map([
            .unsignedInt(2) : .unsignedInt(cointype)
        ])
        
        guard let hexValue = UInt64(parentFingerprint.hexString, radix: 16) else { return nil }
        
        var hdkeyArray:[OrderedMapEntry] = []
        hdkeyArray.append(.init(key: 1, value: .boolean(false)))
        hdkeyArray.append(.init(key: 2, value: .boolean(isPrivate)))
        hdkeyArray.append(.init(key: 3, value: .byteString([UInt8](keydata))))
        hdkeyArray.append(.init(key: 4, value: .byteString([UInt8](chaincode))))
        hdkeyArray.append(.init(key: 5, value: .tagged(CBOR.Tag(rawValue: 305), useInfoWrapper)))
        hdkeyArray.append(.init(key: 6, value: .tagged(CBOR.Tag(rawValue: 304), originsWrapper)))
        hdkeyArray.append(.init(key: 8, value: .unsignedInt(hexValue)))
        let hdKeyWrapper = CBOR.orderedMap(hdkeyArray)
        
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
                
                let (type, network) = URHelper.useInfo(map)
                
                if network == "main" {
                    chain = 0
                } else if network == "test" {
                    chain = 1
                }
                
                if type != "btc" {
                    return nil
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
    
    static func requestXprv(_ xpub: String, _ sourceXfp: String, _ description: String) -> String? {
        var coinType:UInt64 = 0
        
        if Keys.coinType == "1" {
            coinType = 1
        }
        
        let b58 = Base58.decode(xpub)
        let b58Data = Data(b58)
        let depth = b58Data.subdata(in: Range(4...4))
        
        var requestId = UUID().uuidString
        requestId = requestId.replacingOccurrences(of: "-", with: "")
        let uuidByteString = CBOR.byteString([UInt8](Data(value: requestId)))
        
        var originsWrapper:[OrderedMapEntry] = []
        originsWrapper.append(.init(key: 1, value: .array([.unsignedInt(48), true, .unsignedInt(coinType), true, .unsignedInt(0), true, .unsignedInt(2), true])))
        originsWrapper.append(.init(key: 2, value: .unsignedInt(UInt64(sourceXfp, radix: 16) ?? 0)))
        originsWrapper.append(.init(key: 3, value: .unsignedInt(UInt64(depth.hexString) ?? 0)))
        let originsCbor = CBOR.orderedMap(originsWrapper)
        
        var useInfoWrapper:[OrderedMapEntry] = []
        useInfoWrapper.append(.init(key: 2, value: .unsignedInt(1)))
        let useInfoCbor = CBOR.orderedMap(useInfoWrapper)
        
        var hdkeyRequest:[OrderedMapEntry] = []
        hdkeyRequest.append(.init(key: 1, value: .boolean(true)))
        hdkeyRequest.append(.init(key: 2, value: .tagged(CBOR.Tag(rawValue: 304), originsCbor)))
        hdkeyRequest.append(.init(key: 3, value: .tagged(CBOR.Tag(rawValue: 305), useInfoCbor)))
        let hdkeyRequestCbor = CBOR.orderedMap(hdkeyRequest)
        
        var request:[OrderedMapEntry] = []
        request.append(.init(key: 1, value: .tagged(CBOR.Tag(rawValue: UInt64(37)), uuidByteString)))
        request.append(.init(key: 2, value: .tagged(CBOR.Tag(rawValue: UInt64(501)), hdkeyRequestCbor)))
        request.append(.init(key: 3, value: .utf8String(description)))
        
        let cbor = CBOR.orderedMap(request)
        
        guard let rawUr = try? UR(type: "crypto-request", cbor: cbor) else { return nil }
        
        return UREncoder.encode(rawUr)
    }
    
}
