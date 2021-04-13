import Foundation
import Network

protocol BrowserDelegate: AnyObject {
    func removed(service: NWBrowser.Result)
    func added(service: NWBrowser.Result)
}

class Browser {

    enum Interface {
        case peerToPeer
        case localOnly
    }

    weak var delegate: BrowserDelegate?

    var browser: NWBrowser?
    let interface: Interface
    var services: Set<NetService> = []

    init(interface: Interface = .peerToPeer) {
        self.interface = interface
    }

    func startBrowsing(psiOnly: Bool = false) {
        let parameters = NWParameters()
        switch self.interface {
        case .peerToPeer:
            parameters.includePeerToPeer = true
        case .localOnly:
            parameters.requiredInterfaceType = NWInterface.InterfaceType.loopback
        }
        parameters.includePeerToPeer = true
        // Here we could also require AWDL interface and IPv6

        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_airdrop._tcp.", domain: "local."), using: parameters)

        PrivateDrop.testDelegate?.startedBrowsing()
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .failed(let error):
                // Restart the browser if it fails.
                print("Browser failed with \(error), restarting")
                browser.cancel()
                self?.startBrowsing(psiOnly: psiOnly)

            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] _, changes in
            for change in changes {
                switch change {
                case .added(let result):
                    Log.info(
                        system: .client, message: "Bonjour service found:\n %@",
                        String(describing: result))
                    self?.delegate?.added(service: result)
                case .removed(let result):
                    self?.delegate?.removed(service: result)
                default:
                    break
                }
            }
        }

        browser.start(queue: .main)
    }

    func stopBrowsing() {
        if browser?.state == .some(.ready) {
            browser?.cancel()
        }
    }

}
