//
//  PSIImport.swift
//  PrivateDrop-TestAppTests
//
//  Created by Alex - SEEMOO on 24.07.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

import Foundation
import OpenSSL

/// The importer is used to import signed pre-computed values
struct PSISignedValues {

    static public func verify(signedData: Data) throws -> SignedYValues {
        // Get the CA certificate
        let certURL = Bundle.privateDrop.caURL

        // 1. Verify the PKCS7 and get the data
        let pkcs7Verifier = PKCS7Verifier(pkcs7: signedData)
        // Necessary, because our self-signed certificates won't be accepted by the OpenSSL
        let data = try pkcs7Verifier.verify(with: certURL, verifyChain: true)

        let importedY = try PropertyListDecoder().decode(SignedYValues.self, from: data)

        return importedY
    }

    struct SignedYValues: Codable {
        let y: [Data]
    }

    enum Error: Swift.Error {
        case verificationFailed
        case missingInput
    }
}
