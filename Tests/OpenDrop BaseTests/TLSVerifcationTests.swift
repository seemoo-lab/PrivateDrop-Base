//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 16.06.20.
//

import Foundation
import XCTest

@testable import PrivateDrop_Base

class TLSVerifcationTests: XCTestCase {

    var certificatesDir: URL {
        let keysDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent(
                "TestResources/certificates")
        return keysDir
    }

    var appleRootCA: SecCertificate {
        let url = certificatesDir.appendingPathComponent("AppleRootCA.cer")
        let certData = try! Data(contentsOf: url)
        let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, certData as CFData)!
        return certificate
    }

    var appleAuthenticationCA: SecCertificate {
        let url = certificatesDir.appendingPathComponent(
            "Apple Application Integration Certification Authority.crt")
        let certData = try! Data(contentsOf: url)
        let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, certData as CFData)!
        return certificate
    }

    var sampleAppleIDCertificate: SecCertificate {
        let url = certificatesDir.appendingPathComponent("certificate_apple.cer")
        let certData = try! Data(contentsOf: url)
        // PEM Certificate not supported!
        let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, certData as CFData)!
        return certificate
    }

    var invalidCA: SecCertificate {
        let url = certificatesDir.appendingPathComponent("some_ca.crt")
        let certData = try! Data(contentsOf: url)
        let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, certData as CFData)!
        return certificate
    }

    var invalidCert: SecCertificate {
        let url = certificatesDir.appendingPathComponent("some_cert.crt")
        let certData = try! Data(contentsOf: url)
        let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, certData as CFData)!
        return certificate
    }

    func secTrust(from pkcs12: Data) -> sec_trust_t {
        let identity = PrivateDropTLSSupport.identity(fromPKCS12: pkcs12)!
        let sIdentity = sec_identity_copy_ref(identity)!.takeRetainedValue()
        var cert: SecCertificate!
        var status = SecIdentityCopyCertificate(sIdentity, &cert)
        XCTAssertEqual(status, errSecSuccess)
        let certificateArray = [cert]

        var trust: SecTrust!
        status = SecTrustCreateWithCertificates(certificateArray as CFArray, nil, &trust)
        XCTAssertEqual(status, errSecSuccess)
        let osTrust = sec_trust_create(trust)!
        return osTrust
    }

    func testVerifySelfSigned() {
        let keysDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent(
                "TestResources/certificates")
        let certificateURL = keysDir.appendingPathComponent("ServerCertificate.p12")
        let certificate = try! Data(contentsOf: certificateURL)

        let trust = self.secTrust(from: certificate)
        // Verify
        PrivateDropTLSSupport.customCertificateValidation(from: trust) { (result) in
            switch result {
            case .failure(let error):
                XCTFail(String(describing: error))
            case .success: break

            }
        }
    }

    func testVerifyAppleSigned() {
        let certChain = [
            self.sampleAppleIDCertificate, self.appleAuthenticationCA, self.appleRootCA,
        ]
        var trust: SecTrust!
        let status = SecTrustCreateWithCertificates(certChain as CFArray, nil, &trust)
        XCTAssertEqual(status, errSecSuccess)

        let ostrust = sec_trust_create(trust)!

        PrivateDropTLSSupport.customCertificateValidation(from: ostrust) { (result) in
            switch result {
            case .failure(let error):
                XCTFail(String(describing: error))
            case .success: break

            }
        }
    }

    func testVerifyInvalid() {
        let certChain = [self.invalidCert, self.invalidCA]
        var trust: SecTrust!
        let status = SecTrustCreateWithCertificates(certChain as CFArray, nil, &trust)
        XCTAssertEqual(status, errSecSuccess)

        let ostrust = sec_trust_create(trust)!

        PrivateDropTLSSupport.customCertificateValidation(from: ostrust) { (result) in
            switch result {
            case .failure:
                break
            case .success:
                XCTFail("Verified CA that should not be allowed with AirDrop")
            }
        }
    }

    func testLoadRootCA() {
        let cas = PrivateDropTLSSupport.loadAppleRootCAs()
        XCTAssert(cas.count > 0)
        guard let cert = cas.first else { return }
        var name: CFString?
        SecCertificateCopyCommonName(cert, &name)
        XCTAssertNotNil(name)
        XCTAssert(name! as String == "Apple Root CA")
    }

}
