//
//  ContactGenerator.swift
//  PrivateDrop BaseTests
//
//  Created by Alex - SEEMOO on 12.01.21.
//  Copyright © 2021 SEEMOO - TU Darmstadt. All rights reserved.
//

import OpenSSL
import PSI
import XCTest

@testable import PrivateDrop_Base

class ContactGenerator: XCTestCase {

    var encoder: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return encoder
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGenerateContactIds() {
        let testSet = self.generateRandomTestSet(of: 900)
        print(testSet.joined(separator: " "))
    }

    func getSigningCertificateURL() throws -> URL {
        #if os(macOS)
            let certDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
                .appendingPathComponent(
                    "TestResources/certificates")
            return certDir.appendingPathComponent("OpenDrop-PSI-Sign-3.pem")
        #else
            let bundle = Bundle(for: PKCS7Tests.self)
            return bundle.url(forResource: "OpenDrop-PSI-Sign-3", withExtension: "pem")!
        #endif
    }

    func getTrustedSelfSignedCertsURLs() throws -> [URL] {
        #if os(macOS)
            let certDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
                .appendingPathComponent(
                    "TestResources/certificates")
            return [certDir.appendingPathComponent("OpenDrop-PSI-Sign-3.pem")]
        #else
            let bundle = Bundle(for: PKCS7Tests.self)
            return [bundle.url(forResource: "OpenDrop-PSI-Sign-3", withExtension: "pem")!]
        #endif
    }

    func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    func generateRandomTestSet(of size: Int) -> [String] {
        var testSet = [String]()

        for _ in 0..<size {
            testSet.append(self.randomString(length: 20))
        }

        return testSet
    }

    func testGenerateIDFilesForMeasurements() {
        // Initialize PSI
        PSI.initialize(config: .init(useECPointCompression: true))
        let knownIds = ["seemoo-iphone8@mr-alex.dev"]

        let setsToGenerate = [1, 5, 10, 20, 100, 1000]

        for setSize in setsToGenerate {
            do {
                let randomSet = generateRandomTestSet(of: setSize - knownIds.count)
                var ids = knownIds + randomSet
                ids = ids.shuffled()

                let verifier = try Verifier(ids: ids)
                let precomputed = verifier.precompute()

                // Generate the Y plist files
                let yvalues = YValuesExport(y: precomputed.yValues)
                let yData = try encoder.encode(yvalues)

                // Sign the y data
                let signer = PKCS7Signer(dataToSign: yData)
                let signedData = try signer.sign(
                    with: try self.getSigningCertificateURL(), password: "opendrop")

                // Verify the signed data for checking
                let ca = try self.getTrustedSelfSignedCertsURLs()
                let pkcsVerifier = PKCS7Verifier(pkcs7: signedData)
                let verifiedData = try pkcsVerifier.verify(with: ca.first!, verifyChain: true)
                let decoded = try PropertyListDecoder().decode(
                    YValuesExport.self, from: verifiedData)
                XCTAssertEqual(yvalues, decoded)

                // If no error was thrown everything went well and we can export the data
                // Export the y values signed
                let pathURL = URL(fileURLWithPath: #file).deletingLastPathComponent()
                    .appendingPathComponent("TestResources/CMS")
                    .appendingPathComponent("\(setSize)_y.cms")

                try signedData.write(to: pathURL)
                // Export the Other values
                let privatePSIURL = URL(fileURLWithPath: #file).deletingLastPathComponent()
                    .appendingPathComponent("TestResources/CMS")
                    .appendingPathComponent("\(setSize)_other.plist")

                let privatePSI = PrivatePSIValues(
                    a: precomputed.aValues, hashes: precomputed.hashes, ids: ids)
                try encoder.encode(privatePSI).write(to: privatePSIURL)

                // Exported files successfully

            } catch {
                XCTFail(error.localizedDescription)
            }
        }

    }

}

struct YValuesExport: Codable, Equatable {
    let y: [Data]
}

struct PrivatePSIValues: Codable {
    let a: [Data]
    let hashes: [Data]
    let ids: [String]
}
