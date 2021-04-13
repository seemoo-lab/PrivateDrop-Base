//
//  PKCS7_SSL.swift
//  OpenSSL
//
//  Created by Alex - SEEMOO on 23.07.20.
//

import Foundation
import OpenSSLLib

/// Struct to verify PKCS7 messages and extract their signed data
public struct PKCS7Verifier {
    var pkcs7Data: Data

    /// Initialize the verifier with PKCS7 formatted data. The initialized PKCS7 is the one that should be verified later
    /// - Parameter data: PKCS7 formatted data
    public init(pkcs7 data: Data) {
        self.pkcs7Data = data
    }

    /// Verify the PKCS7 data with the given trusted certificate.
    /// - Parameters:
    ///   - trustedCert: An local file URL to a trusted certificate that should be used for verification
    ///   - verifyChain: Set this to false if the verification should not verify the entire chain,
    ///   but rather just the signature. Does not check for any wrongly generated certificates.
    /// - Throws: An error if the verification fails
    /// - Returns: Returns the signed data (actual data that has been signed) if the verification succeeds. Otherwise it will *throw* an error
    public func verify(with trustedCert: URL, verifyChain: Bool = true) throws -> Data {
        let cmsData = self.pkcs7Data
        // Write to temporary file
        let tempDirectory = NSTemporaryDirectory()
        let cmsFilePath = tempDirectory.appending("to_verify.cms")
        let trustedCertPath = trustedCert.path
        let outPath = tempDirectory.appending("cms_out.txt")

        try cmsData.write(to: URL(fileURLWithPath: cmsFilePath))

        let result = verifyCMS(
            trustedCertPath.cString(using: .utf8), cmsFilePath.cString(using: .utf8),
            outPath.cString(using: .utf8))

        // Delete temp files
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: cmsFilePath))

        if result == 0 {
            // Success
            let content = try Data(contentsOf: URL(fileURLWithPath: outPath))

            try? FileManager.default.removeItem(at: URL(fileURLWithPath: outPath))

            return content
        } else {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: outPath))
            throw Error.verificationFailed
        }

    }

    enum Error: Swift.Error {
        case importError
        case verificationFailed
    }
}
