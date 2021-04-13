//
//  PSIPrivateDropTests.swift
//  ASN1Decoder
//
//  Created by Alex - SEEMOO on 20.07.20.
//

import Foundation
import PSI
import XCTest

@testable import PrivateDrop_Base

class PSIPrivateDropOfflineTests: XCTestCase {

    override func setUpWithError() throws {
        PSI.initialize(config: .init(useECPointCompression: true))
    }

    // MARK: - Offline

    /// Client and server are mutual contacts and run the PSI protocol
    func testOfflinePSIInteraction() throws {
        // Server initialization
        var serverContacts = TestSetup.generateRandomTestSet(of: 100)
        let serverContactIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.serverOtherVals
        ).ids

        // Client initialization
        // Client contacts contains server id
        let clientContacts =
            TestSetup.generateRandomTestSet(of: 100) + [serverContactIds.randomElement()!]
        // Client is in server contacts
        let clientContactIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.clientOtherVals
        ).ids
        serverContacts += clientContactIds.shuffled()[0...1]

        let serverConfig = try PrivateDrop.Configuration.Contacts(
            recordData: nil, contactsOnly: true, contacts: serverContacts,
            signedY: Bundle.test.serverSignedY, otherPrecomputedValues: Bundle.test.serverOtherVals)
        let server = PSIController(contactsConfig: serverConfig)

        let clientConfig = try PrivateDrop.Configuration.Contacts(
            recordData: nil, contactsOnly: true, contacts: clientContacts,
            signedY: Bundle.test.clientSignedY, otherPrecomputedValues: Bundle.test.clientOtherVals)
        let client = PSIController(contactsConfig: clientConfig)

        do {
            // 1. Request from client to server
            let verifierResponse = try server?.startPSIServer()

            // 2. Request from client to server
            let finisRequest = try client?.startPSIClient(with: verifierResponse!)
            // 3. Response to client
            let proverResponse = try server?.finishPSIServer(with: finisRequest!)
            _ = try client?.finishPSIClient(with: proverResponse!)

        } catch {
            XCTFail(String(describing: error))
        }

    }

    /// The server is not a contact of the client. Therefore, the finishPSIServer method should throw an error
    func testOfflinePSIInteractionServerNotContact() throws {
        // Server initialization
        var serverContacts = TestSetup.generateRandomTestSet(of: 100)
        _ = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.serverOtherVals
        )
        .ids

        // Client initialization
        // Client contacts contains server id
        let clientContacts = TestSetup.generateRandomTestSet(of: 100)
        // Client is in server contacts
        let clientContactIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.clientOtherVals
        ).ids
        serverContacts += clientContactIds.shuffled()[0...1]

        let serverConfig = try PrivateDrop.Configuration.Contacts(
            recordData: nil, contactsOnly: true, contacts: serverContacts,
            signedY: Bundle.test.serverSignedY, otherPrecomputedValues: Bundle.test.serverOtherVals)
        let server = PSIController(contactsConfig: serverConfig)

        let clientConfig = try PrivateDrop.Configuration.Contacts(
            recordData: nil, contactsOnly: true, contacts: clientContacts,
            signedY: Bundle.test.clientSignedY, otherPrecomputedValues: Bundle.test.clientOtherVals)
        let client = PSIController(contactsConfig: clientConfig)

        do {
            // 1. Request from client to server
            let verifierResponse = try server?.startPSIServer()

            // 2. Request from client to server
            let finisRequest = try client?.startPSIClient(with: verifierResponse!)
            // 3. Response to client
            do {
                _ = try server?.finishPSIServer(with: finisRequest!)
                XCTFail("Request to server did not throw")
            } catch {
                // This should be executed
                XCTAssertTrue(error as! PSIController.Error == .noContactMatch)
            }

        } catch {
            XCTFail(String(describing: error))
        }

    }

    /// The client is not a contact of the server. Therefore, the finishPSIServer method should throw an error
    func testOfflinePSIInteractionClientNotContact() throws {
        // Server initialization
        let serverContacts = TestSetup.generateRandomTestSet(of: 100)
        let serverContactIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.serverOtherVals
        ).ids

        // Client initialization
        // Client contacts contains server id
        let clientContacts: [String] =
            TestSetup.generateRandomTestSet(of: 100) + serverContactIds.shuffled()[0...1]
        // Client is in server contacts
        _ = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.clientOtherVals
        )
        .ids

        let serverConfig = try PrivateDrop.Configuration.Contacts(
            recordData: nil, contactsOnly: true, contacts: serverContacts,
            signedY: Bundle.test.serverSignedY, otherPrecomputedValues: Bundle.test.serverOtherVals)
        let server = PSIController(contactsConfig: serverConfig)

        let clientConfig = try PrivateDrop.Configuration.Contacts(
            recordData: nil, contactsOnly: true, contacts: clientContacts,
            signedY: Bundle.test.clientSignedY, otherPrecomputedValues: Bundle.test.clientOtherVals)
        let client = PSIController(contactsConfig: clientConfig)

        do {
            // 1. Request from client to server
            let verifierResponse = try server?.startPSIServer()

            // 2. Request from client to server
            let finisRequest = try client?.startPSIClient(with: verifierResponse!)
            // 3. Response to client
            let proverResponse = try server?.finishPSIServer(with: finisRequest!)
            do {
                _ = try client?.finishPSIClient(with: proverResponse!)
                XCTFail("Request to server did not throw")
            } catch {
                // This should be executed
                XCTAssertTrue(error as! PSIController.Error == .noContactMatch)
            }

        } catch {
            XCTFail(String(describing: error))
        }

    }

}
