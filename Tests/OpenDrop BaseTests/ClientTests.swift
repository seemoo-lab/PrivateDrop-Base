import Network
import XCTest

@testable import PrivateDrop_Base

class ClientTests: XCTestCase {
    var privateDrop: PrivateDrop = PrivateDrop(with: .testEmpty)
    var receiverDelegate: TestReceiverDelegate? = TestReceiverDelegate()

    override func setUpWithError() throws {
        privateDrop.receiverDelegate = receiverDelegate
        if !privateDrop.server.isRunning {
            try privateDrop.startListening()
        }
    }

    var client: Client = {
        let config = PrivateDrop.Configuration.testClient
        let psiController = PSIController(contactsConfig: config.contacts)!
        let client = Client(
            config: config, psiController: psiController,
            contactsChecker: ContactsChecker(ownContactIds: config.contacts.contacts))
        client.psiOnlyBrowsing = true
        return client
    }()

    class TestPeerObserver: PeerObserver {
        internal init(expectAuthenticated: XCTestExpectation, client: Client) {
            self.expectAuthenticated = expectAuthenticated
            self.client = client
        }

        func peerErrorOccurred(error: Peer.PeerError) {

        }

        func psiStatusChanged(peer: Peer) {
            switch peer.psiStatus {
            case .contact:
                break
            case .nonContact, .notInPeersContacts:
                XCTFail("Wrong PSI status")
            default:
                break
            }
        }

        var peer: Peer?

        let expectAuthenticated: XCTestExpectation
        let client: Client

        func peerStatusChanged(peer: Peer) {
            switch peer.status {
            case .unknown:
                if peer.psiStatus == .notSupported {
                    peer.discover(using: client)
                } else if peer.psiStatus == .unknown {
                    try! peer.startPSI(using: client)
                }

            case .contact:
                self.expectAuthenticated.fulfill()
            case .nonContact:
                Log.debug(system: .client, message: "Not a contact")
            }
        }

    }

    func testClientStart() {

        let expectAuthenticated = XCTestExpectation(description: "Peer is authenticated")

        let observer = TestPeerObserver(expectAuthenticated: expectAuthenticated, client: client)
        client.observer = observer
        client.start()

        wait(for: [expectAuthenticated], timeout: 20.0)
    }

    func testClientAsk() {

        class TestConnectionDelegate: ConnectionDelegate {
            var askingExpectation: XCTestExpectation?
            var acceptExpectation: XCTestExpectation?
            func notify(_ connection: Connection, is status: ConnectionStatus) {
                switch status {
                case .asking:
                    askingExpectation?.fulfill()
                case .accepted:
                    acceptExpectation?.fulfill()
                default:
                    break
                }
            }
        }

        let expectAuthenticated = XCTestExpectation(description: "Peer is authenticated")

        let client = self.client
        let observer = TestPeerObserver(expectAuthenticated: expectAuthenticated, client: client)
        client.observer = observer
        client.start()

        wait(for: [expectAuthenticated], timeout: 10.0)

        let peer = client.peers.first?.value
        let connection = peer?.connect()

        let askingExpectation = XCTestExpectation(description: "Started to ask")
        let acceptExpectation = XCTestExpectation(description: "Peer accepted request")
        let connectionDelegate = TestConnectionDelegate()
        connectionDelegate.askingExpectation = askingExpectation
        connectionDelegate.acceptExpectation = acceptExpectation
        connection?.delegate = connectionDelegate

        let testFile = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent(
                "TestResources/Test-Archive"
            ).appendingPathComponent("owl.png")
        try! connection?.send(file: testFile, using: client)

        wait(for: [askingExpectation, acceptExpectation], timeout: 10.0, enforceOrder: true)
    }

    func testClientUpload() {

        class TestConnectionDelegate: ConnectionDelegate {
            var askingExpectation: XCTestExpectation?
            var acceptExpectation: XCTestExpectation?
            var uploadingExpectation: XCTestExpectation?
            var doneExpectation: XCTestExpectation?

            func notify(_ connection: Connection, is status: ConnectionStatus) {
                switch status {
                case .asking:
                    askingExpectation?.fulfill()
                case .accepted:
                    acceptExpectation?.fulfill()
                case .uploading:
                    uploadingExpectation?.fulfill()
                case .done:
                    doneExpectation?.fulfill()
                default:
                    break
                }
            }
        }

        let expectAuthenticated = XCTestExpectation(description: "Peer is authenticated")

        let client = self.client
        let observer = TestPeerObserver(expectAuthenticated: expectAuthenticated, client: client)
        client.observer = observer
        client.start()

        wait(for: [expectAuthenticated], timeout: 10.0)

        let peer = client.peers.first?.value
        let connection = peer?.connect()

        let askingExpectation = XCTestExpectation(description: "Started to ask")
        let acceptExpectation = XCTestExpectation(description: "Peer accepted request")
        let uploadingExpectation = XCTestExpectation(description: "Started uploading")
        let doneExpectation = XCTestExpectation(description: "Complete upload")
        let connectionDelegate = TestConnectionDelegate()
        connectionDelegate.askingExpectation = askingExpectation
        connectionDelegate.acceptExpectation = acceptExpectation
        connectionDelegate.uploadingExpectation = uploadingExpectation
        connectionDelegate.doneExpectation = doneExpectation
        connection?.delegate = connectionDelegate

        let testFile = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent(
                "TestResources/Test-Archive"
            ).appendingPathComponent("owl.png")
        try! connection?.send(file: testFile, using: client)

        wait(for: [askingExpectation, acceptExpectation], timeout: 10.0, enforceOrder: true)

        wait(for: [uploadingExpectation, doneExpectation], timeout: 10.0, enforceOrder: true)

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

}
