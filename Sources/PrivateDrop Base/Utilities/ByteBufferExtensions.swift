//
//  ByteBufferExtensions.swift
//  ASN1Decoder
//
//  Created by Alex - SEEMOO on 22.07.20.
//

import Foundation
import NIO

extension ByteBuffer {

    /// Reads until next CRLF (\r\n)
    mutating func readLine() -> Data {
        var buffer = Data()

        var sequence = [UInt8]()
        while let bytes = self.readBytes(length: 1) {
            sequence.append(contentsOf: bytes)

            let clrf = [UInt8]([13, 10])
            if sequence == clrf {
                return buffer
            } else if sequence.count == 2 {
                buffer.append(sequence[0])
                sequence.remove(at: 0)
            }
        }
        buffer.append(contentsOf: sequence)

        return buffer
    }
}
