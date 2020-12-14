//
//  PaymentHash.swift
//  GordianSigner
//
//  Created by Peter on 12/11/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation
import LibWally

enum PaymentId {
    
    private static func parseInputs(_ psbt: PSBT) -> String {
        let inputs = psbt.inputs
        var inputStrings = [String]()
        var toReturn = ""
        
        for (i, input) in inputs.enumerated() {
            if let origins = input.origins {
                for (o, origin) in origins.enumerated() {
                    var string = ""
                    let pubkey = origin.key.data.hexString
                    string += pubkey
                    if let amount = input.amount {
                        string += amount.description
                    }
                    inputStrings.append(string)
                    
                    if i + 1 == inputs.count && o + 1 == origins.count {
                        inputStrings = inputStrings.sorted { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }
                        
                        for inputString in inputStrings {
                            toReturn += inputString
                        }

                    }
                }
            }
        }
        
        return toReturn
    }
    
    private static func parseOutputs(_ psbt: PSBT) -> String {
        var toReturn = ""
        var outputStrings = [String]()
        for (i, output) in psbt.outputs.enumerated() {
            var string = ""
            if let address = output.txOutput.address {
                string += address
            }
            
            let amount = output.txOutput.amount.description
            string += amount
            
            if i + 1 == psbt.outputs.count {
                outputStrings = outputStrings.sorted { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }
                for outputString in outputStrings {
                    toReturn += outputString
                }
            }
        }
        
        return toReturn
    }
    
    static func id(_ psbt: PSBT) -> String {
        let toHash = parseInputs(psbt) + parseOutputs(psbt)
        return Encryption.sha256hash(toHash)
    }
}
