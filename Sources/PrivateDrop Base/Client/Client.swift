import Foundation
import NIO
import NIOHTTP1
import NIOTransportServices
import Network

let group = NIOTSEventLoopGroup()

class Client: BrowserDelegate {

    let config: PrivateDrop.Configuration
    var contactsChecker: ContactsChecker?
    let browser: Browser = Browser()
    var peers: [NWEndpoint: Peer] = [:]
    weak var observer: PeerObserver?

    var psiController: PSIController?

    var fileToSend: URL?
    var peerToSend: Peer?

    var psiOnlyBrowsing = false

    private var ongoingRequest: HTTPClient?

    init(
        config: PrivateDrop.Configuration, psiController: PSIController,
        contactsChecker: ContactsChecker? = nil
    ) {
        self.config = config
        self.psiController = psiController
        self.contactsChecker = contactsChecker
        browser.delegate = self
        assert(self.config.contacts.contactsOnly ? self.contactsChecker != nil : true)
    }

    func start(psiOnly: Bool = false) {
        self.psiOnlyBrowsing = psiOnly
        browser.startBrowsing(psiOnly: psiOnly)

        // Remove old peers
        self.peers = [:]
    }

    func added(service: NWBrowser.Result) {
        var supportsPSI = false

        switch service.metadata {
        case .bonjour(let txt):
            if let flags = txt.dictionary["flags"],
                let flagInt = UInt8(flags)
            {
                supportsPSI = (flagInt & AirDropFlags.supportsPSI.rawValue != 0)
            }
        default:
            break
        }

        guard !psiOnlyBrowsing || supportsPSI else { return }

        if let peer = self.peers[service.endpoint] {
            if peer.psiStatus == .notSupported && supportsPSI {
                peer.psiStatus = .unknown
            }
            peer.observer = self.observer
        } else {
            let newPeer = Peer(
                service.endpoint, supportsPSI: supportsPSI, observer: self.observer,
                contactsChecker: self.contactsChecker)
            Log.debug(system: .client, message: "Found new peer %@", String(describing: service))
            self.peers[service.endpoint] = newPeer
        }

    }

    func removed(service: NWBrowser.Result) {

    }

    func stop() {
        browser.stopBrowsing()
    }

    func request(
        with peer: Peer, uri: String,
        method: HTTPMethod = .POST, head: [(String, String)]? = nil,
        body: Data? = nil, write_callback: (() -> Void)? = nil,
        callback: ((HTTPResponseHead, Data?) -> Void)?
    ) {

        let request = HTTPClient(
            with: peer, uri: uri,
            method: method, certificates: self.config.certificates,
            head: head, body: body,
            write_callback: write_callback
        ) { (head, data) in
            self.ongoingRequest = nil
            callback?(head, data)
        }
        self.ongoingRequest = request
    }

}
