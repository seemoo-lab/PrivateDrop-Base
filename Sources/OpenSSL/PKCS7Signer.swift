//
//  PKCS7Signer.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 24.07.20.
//

import Foundation
import OpenSSLLib

/// A struct that allows to sign data in the PKCS7 format
public struct PKCS7Signer {

    /// The data that should be signed
    var dataToSign: Data

    /// Initialize the struct with the data that should be signed.
    /// - Parameter dataToSign: Data that should be signed
    public init(dataToSign: Data) {
        self.dataToSign = dataToSign
    }

    /// Sign the data by using the given certificate and its optional password
    /// - Parameter certificateURL: The url to the certificate (that contains a private key).
    /// This implementation supports PEM files that include a certificate and a key or P12 encrypted files. PEM files have an optional password
    /// - Parameter password: An optional password.
    /// - Throws: Throws an error if the signature generation fails
    /// - Returns: Signed data in PKCS7 format.
    public func sign(with certificateURL: URL, password: String?) throws -> Data {
        let tempDirectory = NSTemporaryDirectory() + "OpenDrop-PSI/"
        let fm = FileManager.default
        try? fm.createDirectory(
            atPath: tempDirectory, withIntermediateDirectories: true, attributes: nil)

        let dataPath = tempDirectory.appending("data.bin")
        try self.dataToSign.write(to: URL(fileURLWithPath: dataPath))
        let certPath = certificateURL.path
        let outPath = tempDirectory.appending("out.cms")

        let certPassword = password?.cString(using: .utf8)

        let result = signCMS(
            dataPath.cString(using: .utf8), certPath.cString(using: .utf8), certPassword,
            outPath.cString(using: .utf8))

        guard result == 0 else {
            try? fm.removeItem(at: URL(fileURLWithPath: tempDirectory))
            throw Error.signFailed
        }

        let cmsData = try Data(contentsOf: URL(fileURLWithPath: outPath))
        try? fm.removeItem(at: URL(fileURLWithPath: tempDirectory))

        return cmsData
    }

    func getSigningCertificate(with certificateURL: URL, passphrase: String?) throws -> SecIdentity {
        let file = try FileWrapper(url: certificateURL, options: .immediate)
        guard let certificateData = file.regularFileContents else {
            throw Error.loadingCertificateFailed
        }

        let importPassphrase = passphrase != nil ? passphrase : ""

        var identityArray: CFArray?
        let status = SecPKCS12Import(
            certificateData as CFData,
            [kSecImportExportPassphrase: importPassphrase] as CFDictionary,
            &identityArray)
        guard status == errSecSuccess,
            let identityDictionaries = identityArray as? [[CFString: Any]],
            let identityRef = identityDictionaries[0][kSecImportItemIdentity]
        else {
            throw Error.loadingCertificateFailed
        }

        // swiftlint:disable force_cast
        let identity = identityRef as! SecIdentity
        // swiftlint:enable force_cast

        return identity
    }

    private func printError() {
        let error = ERR_get_error()
        var errorBuf = [Int8](repeating: 0, count: 1024)
        ERR_error_string(error, &errorBuf)
        print("\(String(cString: errorBuf))")

        // Cert Error string
        let errorStringC = X509_verify_cert_error_string(Int(error))!
        print("Cert error:\n \(String(cString: errorStringC))")
    }

    enum Error: Swift.Error {
        case loadingCertificateFailed
        case signFailed
    }
}
