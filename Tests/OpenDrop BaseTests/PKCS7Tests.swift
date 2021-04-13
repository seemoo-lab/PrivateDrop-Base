//
//  PKCS7Tests.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 23.07.20.
//

import OpenSSL
import XCTest

class PKCS7Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func getSignedYValues() throws -> Data {
        #if os(macOS)
            let cmsDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
                .appendingPathComponent(
                    "TestResources/CMS")
            return try Data(contentsOf: cmsDir.appendingPathComponent("yValues.cms"))
        #else
            let url = Bundle(for: PKCS7Tests.self).url(
                forResource: "yValues", withExtension: "cms")!
            return try Data(contentsOf: url)
        #endif
    }

    func getSenderRecord() throws -> Data {
        #if os(macOS)
            let cmsDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
                .appendingPathComponent(
                    "TestResources/CMS")
            return try Data(contentsOf: cmsDir.appendingPathComponent("senderrecord.data"))
        #else
            let url = Bundle(for: PKCS7Tests.self).url(
                forResource: "senderrecord", withExtension: "data")!
            return try Data(contentsOf: url)
        #endif
    }

    func getTrustedAppleCertsURLs() throws -> [URL] {
        #if os(macOS)
            let certDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
                .appendingPathComponent(
                    "TestResources/certificates")
            return [certDir.appendingPathComponent("AppleRootCA.pem")]
        #else
            let bundle = Bundle(for: PKCS7Tests.self)
            return [bundle.url(forResource: "Apple Root CA.crt", withExtension: "crt")!]
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

    func testPKCSSenderRecord() throws {
        let pkcs7Data = try self.getSenderRecord()

        XCTAssertNotNil(pkcs7Data)

        let pkcs7 = PKCS7Verifier(pkcs7: pkcs7Data)

        let trustedCerts = try self.getTrustedAppleCertsURLs()
        let data = try pkcs7.verify(with: trustedCerts.first!, verifyChain: true)
        let plist = try PropertyListSerialization.propertyList(
            from: data, options: .init(), format: nil)
        print(plist)
        XCTAssertNotNil(plist)
    }

    func testPKCSYValues() throws {
        let pkcs7Data = try self.getSignedYValues()

        XCTAssertNotNil(pkcs7Data)

        self.measure {
            do {
                let pkcs7 = PKCS7Verifier(pkcs7: pkcs7Data)

                let trustedCerts = try self.getTrustedSelfSignedCertsURLs()
                let data = try pkcs7.verify(with: trustedCerts.first!, verifyChain: true)
                let plist = try PropertyListSerialization.propertyList(
                    from: data, options: .init(), format: nil)
                print(plist)
                XCTAssertNotNil(plist)
            } catch {
                XCTFail("Test threw an error \(error)")
            }

        }

    }

    func testSignPKCS7() throws {
        let data = "This is some test string".data(using: .utf8)!

        let signer = PKCS7Signer(dataToSign: data)
        let signedData = try signer.sign(
            with: try self.getSigningCertificateURL(), password: "opendrop")

        // Verify the signed data
        let ca = try self.getTrustedSelfSignedCertsURLs()
        // Verify
        let verifier = PKCS7Verifier(pkcs7: signedData)
        _ = try verifier.verify(with: ca.first!, verifyChain: true)
    }
}
