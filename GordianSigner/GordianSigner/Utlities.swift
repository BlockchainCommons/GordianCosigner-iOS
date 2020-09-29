//
//  Utlities.swift
//  GordianSigner
//
//  Created by Peter on 9/29/20.
//  Copyright © 2020 Blockchain Commons. All rights reserved.
//

import Foundation

public extension Data {
    init<T>(value: T) {
        self = withUnsafePointer(to: value) { (ptr: UnsafePointer<T>) -> Data in
            return Data(buffer: UnsafeBufferPointer(start: ptr, count: 1))
        }
    }

    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.load(as: T.self) }
    }
}
