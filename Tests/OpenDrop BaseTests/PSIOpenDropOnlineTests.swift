//
//  PSIPrivateDropOnlineTests.swift
//  PrivateDrop BaseTests
//
//  Created by Alex - SEEMOO on 20.07.20.
//

import Network
import PSI
import XCTest

@testable import PrivateDrop_Base

class PSIPrivateDropOnlineTests: XCTestCase {
    var testObserver: TestPeerObserver?
    var peer: Peer?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        PSI.initialize(config: .init(useECPointCompression: true))

    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPSIOnline() throws {
        var serverContacts = TestSetup.generateRandomTestSet(of: 100)
        let serverContactIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.serverOtherVals
        ).ids

        // Create the client
        let clientContacts =
            TestSetup.generateRandomTestSet(of: 100) + serverContactIds.shuffled()[0...2]
        let clientIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.clientOtherVals
        ).ids
        serverContacts.append(contentsOf: clientIds[2...3])

        let expect = self.expectation(description: "PSI Online")
        expect.assertForOverFulfill = false

        try self.executeOnlinePSI(
            with: serverContacts, serverSignedY: Bundle.test.serverSignedY,
            serverPSIValues: Bundle.test.serverOtherVals, clientContacts: clientContacts,
            clientSignedY: Bundle.test.clientSignedY, clientPSIValues: Bundle.test.clientOtherVals
        ) { (_, peer) in
            switch peer.psiStatus {
            case .unknown:
                break
            case .nonContact, .notSupported:
                XCTFail("Should not reach this status")
            case .notInPeersContacts:
                XCTFail("Should not reach this status")
            case .contact(let matchingIds):
                expect.fulfill()
                XCTAssertEqual(Set(matchingIds), Set(clientIds[2...3]))

            }

        }
        self.wait(for: [expect], timeout: 60.0)

    }

    func testPSIOnlineClientNotContactOfServer() throws {
        let serverContacts = TestSetup.generateRandomTestSet(of: 100)
        let serverContactIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.serverOtherVals
        ).ids

        // Create the client
        let clientContacts =
            TestSetup.generateRandomTestSet(of: 100) + serverContactIds.shuffled()[0...2]

        let expect = self.expectation(description: "PSI Online")

        try self.executeOnlinePSI(
            with: serverContacts, serverSignedY: Bundle.test.serverSignedY,
            serverPSIValues: Bundle.test.serverOtherVals, clientContacts: clientContacts,
            clientSignedY: Bundle.test.clientSignedY, clientPSIValues: Bundle.test.clientOtherVals
        ) { (_, peer) in
            switch peer.psiStatus {
            case .unknown:
                break
            case .nonContact:
                expect.fulfill()
            case .notInPeersContacts, .notSupported:
                XCTFail("Should not reach this status")
            case .contact:
                XCTFail("Should not reach this status")
            }

        }
        self.wait(for: [expect], timeout: 10.0)
    }

    func testPSIOnlineServerNotContactOfClient() throws {
        var serverContacts = TestSetup.generateRandomTestSet(of: 100)

        // Create the client
        let clientContacts = TestSetup.generateRandomTestSet(of: 100)
        let clientIds = try PropertyListDecoder().decode(
            PrivatePSIValues.self, from: Bundle.test.clientOtherVals
        ).ids
        serverContacts.append(contentsOf: clientIds.shuffled()[0...1])

        let expect = self.expectation(description: "PSI Online")

        try self.executeOnlinePSI(
            with: serverContacts, serverSignedY: Bundle.test.serverSignedY,
            serverPSIValues: Bundle.test.serverOtherVals, clientContacts: clientContacts,
            clientSignedY: Bundle.test.clientSignedY, clientPSIValues: Bundle.test.clientOtherVals
        ) { (_, peer) in
            switch peer.psiStatus {
            case .unknown:
                break
            case .nonContact, .notSupported:
                XCTFail("Should not reach this status")
            case .notInPeersContacts:
                expect.fulfill()
            case .contact:
                XCTFail("Should not reach this status")
            }

        }
        self.wait(for: [expect], timeout: 10.0)
    }

    func executeOnlinePSI(
        with serverContacts: [String], serverSignedY: Data, serverPSIValues: Data,
        clientContacts: [String], clientSignedY: Data, clientPSIValues: Data,
        callback: @escaping (String, Peer) -> Void
    ) throws {

        let config = try PrivateDrop.Configuration.testServer(
            with: serverContacts, and: serverSignedY, otherVals: serverPSIValues)
        let psiController = PSIController(contactsConfig: config.contacts)!

        let server = Server(config: config, psiController: psiController)
        try server.startServer(
            port: 8443,
            completion: { [weak self] _, _ in
                do {
                    let config = try PrivateDrop.Configuration.testClient(
                        with: clientContacts, and: clientSignedY, otherVals: clientPSIValues)
                    let psiController = PSIController(contactsConfig: config.contacts)!
                    let client = Client(
                        config: config, psiController: psiController,
                        contactsChecker: ContactsChecker(ownContactIds: clientContacts))

                    // Connect the client
                    let host = NWEndpoint.Host.ipv6(IPv6Address("::1")!)
                    let port = NWEndpoint.Port(rawValue: UInt16(server.port))!

                    self?.testObserver = TestPeerObserver(callback: callback)

                    let peer = Peer(
                        NWEndpoint.hostPort(host: host, port: port), supportsPSI: true,
                        observer: self?.testObserver)
                    self?.peer = peer
                    peer.contactsChecker = client.contactsChecker
                    try peer.startPSI(using: client)
                } catch {
                    XCTFail("\(error)")
                }

            })

    }

    class TestPeerObserver: PeerObserver {
        func peerErrorOccurred(error: Peer.PeerError) {

        }

        let callback: (_ functionName: String, _ peer: Peer) -> Void

        init(callback: @escaping (_ functionName: String, _ peer: Peer) -> Void) {
            self.callback = callback
        }

        func peerStatusChanged(peer: Peer) {
            callback(#function, peer)
        }

        func psiStatusChanged(peer: Peer) {
            callback(#function, peer)
        }

    }

}
