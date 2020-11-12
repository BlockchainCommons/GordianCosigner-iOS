//
//  PSBTParser.swift
//  GordianSigner
//
//  Created by Peter on 11/12/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import LibWally

class PSBTParser {
    
    class func parse(_ psbt: String) {
        var psbtToParse:PSBT!
        
        if let mainnetPsbt = try? PSBT(psbt, .mainnet) {
            print("that is mainnet")
            psbtToParse = mainnetPsbt
            
        } else if let testnetPsbt = try? PSBT(psbt, .testnet) {
            print("that is testnet")
            psbtToParse = testnetPsbt
            
        } else {
            print("that is not a valid psbt")
        }
        
        let inputs = psbtToParse.inputs
        let outputs = psbtToParse.outputs
        
        for input in inputs {
            if let origins = input.origins {
                for origin in origins {
                    let path = origin.value.path
                    print("input path: \(path.description)")
                    
                    let key = origin.key
                    print("input pubKey: \(key.data.hexString)")
                }
            } else {
                print("no input origins available")
            }
            
            if let satoshis = input.amount {
                print("input satoshis: \(satoshis)")
            }
        }
        
        for output in outputs {
            if let origins = output.origins {
                for origin in origins {
                    let path = origin.value.path
                    print("output path: \(path.description)")
                    
                    let key = origin.key
                    print("output pubKey: \(key.data.hexString)")
                }
            }
            
            let satoshis = output.txOutput.amount
            print("output satoshis: \(satoshis)")
            
            if let address = output.txOutput.address {
                print("output address: \(address.description)")
            }
        }
        
        if let fee = psbtToParse.fee {
            print("psbt fee: \(fee)")
        }
    }
}
