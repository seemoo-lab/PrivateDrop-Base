//
//  PSIController.swift
//  ASN1Decoder
//
//  Created by Alex - SEEMOO on 20.07.20.
//

import Foundation
import OpenSSL
import PSI

// swiftlint:disable force_try
class PSIController {

    enum Error: Swift.Error {
        case stateError
        case noContactMatch
    }

    var verifier: Verifier
    var prover: Prover

    var config: PrivateDrop.Configuration.Contacts
    var isContactOffPeer = false

    var verifyPKCS7Chain = true

    var valuesCached: Bool {
        self.prover.cachedU != nil
    }

    var signedY: Data

    init?(contactsConfig: PrivateDrop.Configuration.Contacts) {
        guard let yValues = contactsConfig.yValues,
            let signedY = contactsConfig.signedY,
            let otherValues = contactsConfig.otherPrecomputedValues
        else { return nil }

        self.config = contactsConfig
        PSI.initialize(config: .init(useECPointCompression: true))
        self.prover = try! Prover(contacts: contactsConfig.contacts)

        self.verifier = try! Verifier(
            ids: otherValues.ids, y: yValues, a: otherValues.a, hashes: otherValues.hashes)
        self.signedY = signedY
    }

    // MARK: - Server PSI

    func startPSIServer() throws -> PSIVerifierResponse {
        // Initialize the 1st round verifier
        return PSIVerifierResponse(signedY: signedY)
    }

    func finishPSIServer(with finishRequest: PSIFinisRequest) throws -> PSIProverResponse {

        // Convert to BN and ECC
        let zECC = finishRequest.prover.z.map(ECC.readPoint(from:))
        let pokAsBN = finishRequest.prover.pokAS.map(ECC.readPoint(from:))
        let pokZBN = BN.bigNumberFromBinary(data: finishRequest.prover.pokZ)

        // We do not use the matching contact identifiers here
        try _ = self.matchContacts(
            zECC: zECC, pokAsBN: pokAsBN, pokZBN: pokZBN, u: finishRequest.prover.u)

        let proverResponse = try self.generateProverResponse(
            signedYValues: finishRequest.verifier.signedY)

        return proverResponse
    }

    func matchContacts(zECC: [ec_t], pokAsBN: [ec_t], pokZBN: bn_t, u: [Data]) throws -> [String] {
        // 1. Verify  the prover response

        PrivateDrop.testDelegate?.startVerifying()

        // Throws if the verification fails
        try verifier.verifyPOK(z: zECC, pokZ: pokZBN, pokAs: pokAsBN)

        PrivateDrop.testDelegate?.verified()
        PrivateDrop.testDelegate?.startCalculatingV()
        // Done after verification succeeded
        verifier.calculateV(z: zECC)
        PrivateDrop.testDelegate?.calculatedV()

        PrivateDrop.testDelegate?.startIntersecting()
        // Check if contact
        let matchingContacts = verifier.intersect(with: u)
        PrivateDrop.testDelegate?.intersected()

        guard !matchingContacts.isEmpty else {
            throw Error.noContactMatch
        }

        self.isContactOffPeer = true

        return matchingContacts
    }

    func generateProverResponse(signedYValues: Data) throws -> PSIProverResponse {
        // Generate prover values
        let prover = self.prover

        // Verify the signed y values
        let yValueData = try PKCS7Verifier(pkcs7: signedYValues).verify(
            with: Bundle.privateDrop.caURL, verifyChain: self.verifyPKCS7Chain)

        let yValues = try PropertyListDecoder().decode(
            PSISignedValues.SignedYValues.self, from: yValueData)

        let y_ec = yValues.y.map(ECC.readPoint(from:))

        PrivateDrop.testDelegate?.startCalculatingZ()
        let z_ec = prover.generateZ(from: y_ec)
        let z = z_ec.map(ECC.writePointToData(point:))
        PrivateDrop.testDelegate?.calculatedZ()

        PrivateDrop.testDelegate?.startCalculatingPOK()
        let (pok_A_ec, pokZ_bn) = prover.generatePoK(from: y_ec, z: z_ec)
        let pokAs = pok_A_ec.map(ECC.writePointToData(point:))
        let pokZ = BN.writeToBinary(num: pokZ_bn)
        PrivateDrop.testDelegate?.calculatedPOK()

        let u = prover.generateUForVerifier()

        let proverResponse = PSIProverResponse(z: z, pokAS: pokAs, pokZ: pokZ, u: u)

        return proverResponse
    }

    // MARK: - Client PSI

    func startPSIClient(with verifierResponse: PSIVerifierResponse) throws -> PSIFinisRequest {
        // 1st Round - Prover

        let proverResponse = try self.generateProverResponse(
            signedYValues: verifierResponse.signedY)

        // 2nd Round - Verifier

        // Create request
        return PSIFinisRequest(
            verifier: PSIVerifierResponse(signedY: self.signedY), prover: proverResponse)
    }

    func finishPSIClient(with proverResponse: PSIProverResponse) throws -> [String] {

        // Convert to BN and ECC
        let zECC = proverResponse.z.map(ECC.readPoint(from:))
        let pokAsBN = proverResponse.pokAS.map(ECC.readPoint(from:))
        let pokZBN = BN.bigNumberFromBinary(data: proverResponse.pokZ)

        let matchingContacts = try self.matchContacts(
            zECC: zECC, pokAsBN: pokAsBN, pokZBN: pokZBN, u: proverResponse.u)

        return matchingContacts
    }
}

struct PSIVerifierResponse: Codable {
    /// Y EC-Points converted to binary data
    //    var y : [Data]?

    /// Pre-computed and signed y values (generated by Apple in future). Those are stored in PKCS7 Format and should be verified with the OpenDropCa.cer
    var signedY: Data
}

struct PSIProverResponse: Codable {
    var z: [Data]
    var pokAS: [Data]
    var pokZ: Data
    var u: [Data]
}

struct PSIFinishResponse: Codable {
    var proverResponse: PSIProverResponse
    var ReceiverRecordData: Data?
}

struct PSIFinisRequest: Codable {
    var verifier: PSIVerifierResponse
    var prover: PSIProverResponse
}
