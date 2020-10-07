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

    static func makeBytesUR(_ data: Data) -> UR {
        let cbor = CBOR.byteString(data.bytes).encode().data
        return try! UR(type: "psbt", cbor: cbor)
    }
    
}
