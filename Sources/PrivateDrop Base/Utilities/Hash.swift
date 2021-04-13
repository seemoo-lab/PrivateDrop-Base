//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 22.06.20.
//

import Crypto
import Foundation

struct Hash {
    static func sha1(string: String) throws -> Data {
        var sha1 = Crypto.Insecure.SHA1()
        if let input = string.data(using: .utf8) {
            sha1.update(data: input)
        } else if let input = string.data(using: .ascii) {
            sha1.update(data: input)
        } else {
            throw HashError.invalidEncoding
        }

        let digest = sha1.finalize()
        return Data(digest)
    }

    static func sha256(string: String) throws -> Data {
        var sha256 = Crypto.SHA256()
        if let input = string.data(using: .utf8) {
            sha256.update(data: input)
        } else if let input = string.data(using: .ascii) {
            sha256.update(data: input)
        } else {
            throw HashError.invalidEncoding
        }

        let digest = sha256.finalize()
        return Data(digest)
    }
}

enum HashError: Error {
    case invalidEncoding
}
