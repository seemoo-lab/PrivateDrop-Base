//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Foundation
import Network
import PSI
import XCTest

@testable import PrivateDrop_Base

final class PrivateDrop_ServerTests: XCTestCase {

    var expectation: XCTestExpectation?
    var service: NetService?
    var server: Server?

    var client: Client = {
        let config = PrivateDrop.Configuration.testClient
        let psiController = PSIController(contactsConfig: config.contacts)!
        let client = Client(
            config: config, psiController: psiController,
            contactsChecker: ContactsChecker(ownContactIds: config.contacts.contacts))
        client.psiOnlyBrowsing = true
        return client
    }()

    func startServer() {
        guard server == nil else { return }
        do {
            let config = PrivateDrop.Configuration.testEmpty
            let psiController = PSIController(contactsConfig: config.contacts)
            let server = Server(config: config, psiController: psiController!)
            self.server = server
            try server.startServer(
                port: 8443,
                completion: { _, _ in

                })
        } catch let error {
            XCTFail(String(describing: error))
        }
    }

    override func setUpWithError() throws {
        PSI.initialize(config: .init(useECPointCompression: true))
    }

    /// This tests starts a server and waits for an incoming connection. To run the test its best to use PrivateDrop Python
    func testDiscover() {
        guard TestConfig.runTest() else { return }

        let expect = self.expectation(description: "Listening")
        expect.assertForOverFulfill = false

        let privateDrop = PrivateDrop(
            with: try! .testServer(
                and: Bundle.test.serverSignedY, otherVals: Bundle.test.serverOtherVals)
        )

        let client = self.client

        do {
            try privateDrop.startListening()
            sleep(2)

            let succeeded = {
                privateDrop.stopListening()
                expect.fulfill()
                client.stop()
            }

            let host = NWEndpoint.Host.ipv6(IPv6Address("::1")!)
            let port = NWEndpoint.Port(rawValue: UInt16(privateDrop.server.port))!
            let checker = ContactsChecker(ownContactIds: client.config.contacts.contacts)
            checker.computeHashes()
            let testObserver = TestObserver(succeeded: succeeded, privateDrop: privateDrop)
            let peer = Peer(
                NWEndpoint.hostPort(host: host, port: port), supportsPSI: true,
                observer: testObserver,
                contactsChecker: checker)

            peer.discover(using: client)

            self.wait(for: [expect], timeout: 12)
            privateDrop.stopListening()

        } catch let error {
            XCTFail(String(describing: error))
        }

        class TestObserver: PeerObserver {
            func peerErrorOccurred(error: Peer.PeerError) {

            }

            let succeeded: () -> Void
            let privateDrop: PrivateDrop

            init(succeeded: @escaping () -> Void, privateDrop: PrivateDrop) {
                self.succeeded = succeeded
                self.privateDrop = privateDrop
            }

            func peerStatusChanged(peer: Peer) {
                switch peer.status {
                case .contact, .nonContact:
                    switch peer.endpoint {
                    case .hostPort(host: _, let port):
                        if port.rawValue == privateDrop.server.port {
                            succeeded()
                        }
                    default:
                        break
                    }

                default:
                    break
                }
            }

            func psiStatusChanged(peer: Peer) {

            }
        }

    }

    /// This test will wait for an external client (like local mac) to search for AirDrop
    func testDiscoverIntegrationTest() {
        guard TestConfig.runTest() else { return }

        let expect = self.expectation(description: "Listening")
        expect.assertForOverFulfill = false

        let timer: Timer!

        let privateDrop = PrivateDrop(with: .testEmpty)

        do {
            timer = Timer.scheduledTimer(
                withTimeInterval: 30, repeats: false,
                block: { (_) in
                    XCTFail("Client could not discover server")
                    privateDrop.stopListening()
                    expect.fulfill()
                })

            privateDrop.receiverDelegate = TestPrivateDropObserver(callback: { (fn, _) in
                if fn.contains("discovered") {
                    privateDrop.stopListening()
                    expect.fulfill()
                    timer.invalidate()
                }
            })

            try privateDrop.startListening()

            self.wait(for: [expect], timeout: 31)

        } catch let error {
            XCTFail(String(describing: error))
        }

    }

    func testContact() {
        let senderRecord = RecordData.testSenderRecord
        let checker = ContactsChecker(ownContactIds: ["seemoo-iphone8@mr-alex.dev"])
        checker.computeHashes()
        let result = checker.checkIfContact(senderRecord: senderRecord)

        XCTAssertGreaterThan(result.count, 0)
    }

    // MARK: Ask

    func filesToSend() throws -> [URL] {
        let archiveDirectory = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent("TestResources/Test-Archive")

        return [archiveDirectory]
    }

    func testAsk() throws {
        let config = PrivateDrop.Configuration.testEmpty
        let psiController = PSIController(contactsConfig: config.contacts)
        let server = Server(config: .testEmpty, psiController: psiController!)
        let recDelegate = TestReceiverDelegate()
        server.receiverDelegate = recDelegate
        try server.startServer(
            port: 8443,
            completion: { _, _ in

            })
        sleep(1)

        let client = self.client

        // Connect the client
        let host = NWEndpoint.Host.ipv6(IPv6Address("::1")!)
        let port = NWEndpoint.Port(rawValue: UInt16(server.port))!
        let peer = Peer(
            NWEndpoint.hostPort(host: host, port: port), supportsPSI: false, observer: nil)

        let expect = self.expectation(description: "Ask request")
        let connection = Connection(peer: peer)
        let delegate = TestConnectionDelegate(callback: { (_, conn) in
            switch conn.status {
            case .accepted:
                expect.fulfill()
            default:
                break
            }
        })
        connection.delegate = delegate

        try connection.send(files: try self.filesToSend(), using: client)
        self.wait(for: [expect], timeout: 50)
    }

    func testUpload() throws {
        let privateDrop = PrivateDrop(with: .testEmpty)
        try privateDrop.startListening()
        sleep(1)

        let expect = self.expectation(description: "Upload")

        let observer = TestPrivateDropObserver(callback: { (functionName, _) in
            if functionName.contains("receivedFiles") {
                // Upload succeeded
                expect.fulfill()
            }
        })

        privateDrop.server.receiverDelegate = observer

        let client = self.client

        // Connect the client
        let host = NWEndpoint.Host.ipv6(IPv6Address("::1")!)
        let port = NWEndpoint.Port(rawValue: UInt16(privateDrop.server.port))!
        let peer = Peer(
            NWEndpoint.hostPort(host: host, port: port), supportsPSI: false, observer: nil)

        let connection = Connection(peer: peer)
        try connection.send(files: try self.filesToSend(), using: client)

        self.wait(for: [expect], timeout: 10)
    }

    class TestConnectionDelegate: ConnectionDelegate {

        let callback: (_ functionName: String, _ conn: Connection) -> Void

        init(callback: @escaping (_ functionName: String, _ conn: Connection) -> Void) {
            self.callback = callback
        }

        func notify(_ connection: Connection, is status: ConnectionStatus) {
            self.callback(#function, connection)
        }
    }

    class TestPrivateDropObserver: PrivateDropReceiverDelegate {
        func discovered(with status: Peer.Status) {

        }

        func receivedAsk(
            request: AskRequestBody, matchingContactId: [String]?,
            userResponse: @escaping (Bool) -> Void
        ) {
            self.callback(#function, request)
            userResponse(true)
        }

        func errorOccurred(error: Error) {

        }

        func privateDropReady() {

        }

        let callback: (String, Any?) -> Void

        init(callback: @escaping (String, Any?) -> Void) {
            self.callback = callback
        }

        func discovered() {
            self.callback(#function, nil)
        }

        func receivedFiles(at: URL) {
            self.callback(#function, at)
        }

        func receivedAsk(request: AskRequestBody) {
            self.callback(#function, request)
        }
    }

    class TestReceiverDelegate: PrivateDropReceiverDelegate {

        let discovered_cb: ((Peer.Status) -> Void)?
        let receivedFiles_cb: ((URL) -> Void)?

        init(discovered: ((Peer.Status) -> Void)? = nil, receivedFiles: ((URL) -> Void)? = nil) {
            self.discovered_cb = discovered
            self.receivedFiles_cb = receivedFiles
        }

        func discovered(with status: Peer.Status) {

        }

        func receivedFiles(at: URL) {

        }

        func receivedAsk(
            request: AskRequestBody, matchingContactId: [String]?,
            userResponse: @escaping (Bool) -> Void
        ) {

            // Always accept ask requests
            userResponse(true)
        }

        func errorOccurred(error: Error) {

        }

        func privateDropReady() {

        }
    }

    static var allTests = [
        ("testDiscover", testDiscover)
    ]

}

// MARK: - NetServiceBrowserDelegate
extension PrivateDrop_ServerTests: NetServiceBrowserDelegate {
    func netServiceBrowser(
        _ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool
    ) {

        print("Found service ", String(describing: service))

        if service.name == self.service?.name {
            browser.stop()
            self.expectation?.fulfill()
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        XCTFail()
    }

}
