//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 17.06.20.
//

import Foundation
import OpenSSL
import Security

typealias SenderRecordValidationCallback = (_ pkcs7Data: Data) -> Bool
// swiftlint:disable force_cast
struct RecordData: Codable, Equatable {
    let Version: Int
    let altDsID: String
    let encDsID: String
    let SuggestValidDuration: Int
    let ValidAsOf: Date
    let ValidatedEmailHashes: [String]
    let ValidatedPhoneHashes: [String]

    /// Sender Records are shared with signatures that are contained in a CMS.
    /// - Parameter cms: CMS Data blob with signature and actual data
    static func from(cms: Data) throws -> RecordData {

        let verifier = PKCS7Verifier(pkcs7: cms)

        let appleCA = Bundle.privateDrop.url(forResource: "Apple Root CA", withExtension: "crt")!

        let signedData = try verifier.verify(with: appleCA, verifyChain: true)

        let senderRecord = try PropertyListDecoder().decode(RecordData.self, from: signedData)

        return senderRecord

    }

    // Does not work as expected
    //    static func validateSignature(sig: SignatureInfo) throws -> Bool {
    //        guard let certificate = self.getSingingCertificate(),
    //            let signatureData = sig.signatureData,
    //            let signedAttributesValue = sig.signedAttributes?.rawValue
    //            else {throw CMSError.decodingFailed}
    //
    //
    //
    //        let publicKey = SecCertificateCopyKey(certificate)!
    //
    //        let signingAlgorithm = SecKeyAlgorithm.rsaSignatureRaw
    //        guard SecKeyIsAlgorithmSupported(publicKey, SecKeyOperationType.verify, signingAlgorithm)
    //            else {throw CMSError.algorithmNotSupported}
    //
    //        var verifyError: Unmanaged<CFError>?
    //        let valid = SecKeyVerifySignature(publicKey,
    //                                          signingAlgorithm,
    //                                          signedAttributesValue as CFData,
    //                                          signatureData as CFData,
    //                                          &verifyError)
    //
    //
    //        return valid
    //    }

    static func getSingingCertificate() -> SecCertificate? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: "Apple Application Integration 2 Certification Authority",
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]

        var result: CFTypeRef?
        let osstatus = SecItemCopyMatching(query as CFDictionary, &result)
        guard osstatus == errSecSuccess else { return nil }

        let certificateData = result as! CFData
        let certificate = SecCertificateCreateWithData(nil, certificateData)

        return certificate
    }

}

enum CMSError: Error {
    case signatureVerificationFailed
    case algorithmNotSupported
    case decodingFailed
}
