//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 16.06.20.
//

import Foundation
import Network

struct PrivateDropTLSSupport {

    static func loadAppleRootCAs() -> [SecCertificate] {
        let rootCAs = loadAppleRootCAsFromSystem()
        if rootCAs.isEmpty {
            return loadAppleRootCAsFromFile()
        }
        return rootCAs
    }

    private static func loadAppleRootCAsFromSystem() -> [SecCertificate] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: "AppleIncRootCertificate",
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnData: true,
        ]

        var result: CFTypeRef?
        let osstatus = SecItemCopyMatching(query as CFDictionary, &result)
        guard osstatus == errSecSuccess,
            let certificateData = result as? [CFData]
        else { return [] }

        let certificates = certificateData.compactMap { SecCertificateCreateWithData(nil, $0) }

        return certificates
    }

    private static func loadAppleRootCAsFromFile() -> [SecCertificate] {

        let certPath: URL
        #if os(macOS)
            certPath = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("AppleIncRootCertificate.cer")
        #else
            certPath = Bundle(for: PrivateDrop.self).url(
                forResource: "Apple Root CA", withExtension: "crt")!
        #endif
        let certFile = try? FileHandle(forReadingFrom: certPath)
        let certData = certFile?.readDataToEndOfFile()
        let cert = SecCertificateCreateWithData(nil, (certData ?? Data()) as CFData)

        if let cer = cert {
            return [cer]
        } else {
            return []
        }
    }

    // swiftlint:disable force_cast
    static func identity(fromPKCS12 pkcs12Data: Data) -> sec_identity_t? {
        // Server certificate (Identity)
        var identityArray: CFArray?
        let status = SecPKCS12Import(
            pkcs12Data as CFData, [kSecImportExportPassphrase: "opendrop"] as CFDictionary,
            &identityArray
        )
        guard status == noErr,
            let identityDictionaries = identityArray as? [[CFString: Any]],
            let identityRef = identityDictionaries[0][kSecImportItemIdentity],
            let certificates = identityDictionaries[0][kSecImportItemCertChain]
        else {
            let errorMessage = SecCopyErrorMessageString(status, nil) as String?
            Log.error(
                system: .server,
                message: "Could not load TLS certificate. Using no server certificate.\nERROR: %@",
                String(describing: errorMessage))
            return nil
        }

        let identity = identityRef as! SecIdentity
        let certArray = certificates as! CFArray
        // let os_identity = sec_identity_create(identity)!
        let os_identity = sec_identity_create_with_certificates(identity, certArray)
        return os_identity
    }

    static func secTrust(from os_trust: sec_trust_t) -> SecTrust {
        return sec_trust_copy_ref(os_trust).takeRetainedValue()
    }

    static func validateCertificateChain(from trust: SecTrust) -> Bool {
        // Verify by using the Apple root CA
        let rootCAs: [SecCertificate]

        rootCAs = PrivateDropTLSSupport.loadAppleRootCAs()

        SecTrustSetAnchorCertificates(trust, rootCAs as CFArray)
        // Disable hostname verification
        let policy = SecPolicyCreateSSL(true, nil)
        SecTrustSetPolicies(trust, policy)

        var error: CFError?
        let result = SecTrustEvaluateWithError(trust, &error)

        guard error == nil else {
            // let err = error as! Error
            // Log.error(system: .server, message: "Failed validating client certificate %@", String(describing: err))
            return false
        }

        return result
    }

    static func customCertificateValidation(
        from os_trust: sec_trust_t, verifcationBlock: (Result<VerificationResult, TLSError>) -> Void
    ) {
        // Should be (Apple root CA) - Apple CA - iCloud Leaf
        let trust = PrivateDropTLSSupport.secTrust(from: os_trust)
        let noOfCertificates = SecTrustGetCertificateCount(trust)
        guard noOfCertificates > 0 else {
            verifcationBlock(.failure(.noCertificates))
            return
        }

        self.saveCertificates(from: trust)

        // Verify by using the Apple root CA
        let result = PrivateDropTLSSupport.validateCertificateChain(from: trust)
        if result {
            // Get the CN, because it needs to be present in the record data as well
            // 0 = Leaf cert
            let leafCertificate = SecTrustGetCertificateAtIndex(trust, 0)!
            var cn: CFString?
            SecCertificateCopyCommonName(leafCertificate, &cn)
            guard let commonName = cn as String? else {
                // Failed, because CN is missing
                verifcationBlock(.failure(.missingCN))
                return
            }
            let certificateData: Data = SecCertificateCopyData(leafCertificate) as Data

            verifcationBlock(
                .success(
                    VerificationResult(
                        commonName: commonName, selfSigned: false, certificate: certificateData)))
        } else if noOfCertificates == 1 {
            // Self-Signed certificates are supported as well!
            let leafCertificate = SecTrustGetCertificateAtIndex(trust, 0)!
            let certificateData: Data = SecCertificateCopyData(leafCertificate) as Data

            verifcationBlock(
                .success(
                    VerificationResult(
                        commonName: nil, selfSigned: true, certificate: certificateData)))
        } else {
            verifcationBlock(.failure(.validationFailed))
        }
    }

    static func saveCertificates(from trust: SecTrust) {
        #if DEBUG && os(macOS)
            let noOfCertificates = SecTrustGetCertificateCount(trust)
            guard
                let folderURL = FileManager.default.urls(
                    for: .desktopDirectory, in: .userDomainMask
                ).first
            else { return }

            for i in 0..<noOfCertificates {
                let cert = SecTrustGetCertificateAtIndex(trust, i)!
                var cn: CFString?
                SecCertificateCopyCommonName(cert, &cn)

                let name = cn as String? ?? "cert"
                let certData = SecCertificateCopyData(cert) as Data
                try? certData.write(to: folderURL.appendingPathComponent("\(name).crt"))
            }

        #endif
    }

    public enum TLSError: Error {
        case missingCN
        case noCertificates
        case validationFailed
    }

    public struct VerificationResult {
        let commonName: String?
        let selfSigned: Bool
        let certificate: Data
    }
}

protocol TLSHandler: AnyObject {
    func tlsOptions(using certConfig: PrivateDrop.Configuration.Certificates) -> NWProtocolTLS.Options
}
