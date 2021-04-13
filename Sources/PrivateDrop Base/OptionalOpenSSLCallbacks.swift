//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 22.06.20.
//

import Foundation

/// This protocol can be implemented by an app that links this Swift Package.
/// Some of the security features need OpenSSL support and SPM cannot include binaries until Swift 5.3 (Xcode 12 beta)
protocol OptionalOpenSSLCallbacks {
    /// A function to verify a pkcs7 encoded. Can be done as explained in the StackOverflow example by using the OpenSSL.
    /// https://stackoverflow.com/a/20039394/1203713
    /// - Parameter pkcs7Data: PKCS7 Encoded data in DER Format
    /// - Returns: True if the verification succeeded
    static func verifyPKCS7SenderRecord(pkcs7Data: Data) -> Bool
}
