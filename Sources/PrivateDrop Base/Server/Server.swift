//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Foundation
import Libarchive
import NIOHTTP1
import NIOSSL
import NIOTransportServices
import Network
import PSI

protocol PrivateDropServerDelegate: AnyObject {
    func serverStopped(withError error: Error?)
}

/// The PrivateDrop Server implementation. The server is used for the receiver behaviour to be found by other PrivateDrop clients and to receive files.
class Server {

    /// The delegate can be set to receive errors and when the server stopped.
    weak var delegate: PrivateDropServerDelegate?

    /// Delegate has to be set to handle receiving files by the wrapping application
    weak var receiverDelegate: PrivateDropReceiverDelegate?

    /// True if the server is running
    private(set) var isRunning: Bool = false

    /// Current configuration
    var config: PrivateDrop.Configuration

    /// Contacts checker to find matching contacts
    var contactsChecker: ContactsChecker?

    // Swift NIO Server implementation.
    private var server: HTTP1Server?
    /// The Dispatch Queue on which the server runs
    private var serverQueue: DispatchQueue?

    /// The last  peer connected
    internal var lastPeer: ServerPeer?
    /// An array of peers that have connected.
    internal private(set) var peers = [ServerPeer]()

    /// Handle's PSI on the server side
    var psi: PSIController?

    /// The port on which the server runs
    internal var port: Int {
        self.server?.port ?? 8443
    }

    init(
        config: PrivateDrop.Configuration, psiController: PSIController,
        contactsChecker: ContactsChecker? = nil
    ) {
        self.config = config
        self.psi = psiController
        self.contactsChecker = contactsChecker
    }

    /// Start the Swift NIO HTTPS Server on a given port.
    /// - Parameters:
    ///   - port: The port on which the server should start
    ///   - completion: Completion handler called after the server bound to an address. If the port has changed this is reported in the completion with the **second** argument
    ///   - host: The host address to which is bound
    ///   - port: The port to which the server has bound
    func startServer(port: Int, completion: @escaping (_ host: String, _ port: Int) -> Void) throws {
        self.serverQueue = DispatchQueue(label: "HTTP Server", qos: .background)
        self.serverQueue?.async {
            self.server = HTTP1Server(tlsHandler: self)
            self.server?.addRoutes(routes: self.routes)
            self.isRunning = true
            self.server?.start(
                port: port, certificates: self.config.certificates, completion: completion)
        }
    }

    /// Stops the running server
    func stopServer() {
        self.isRunning = false
        self.server?.shutdown()
        self.server = nil
        self.serverQueue = nil
    }

    /// Checks the validity of the record data and checks if the peer is a contact.
    func performContactCheck(
        with senderRecordEncoded: Data, peer: ServerPeer, contactsChecker: ContactsChecker
    ) throws -> HTTPResponseStatus {

        let senderRecord = try RecordData.from(cms: senderRecordEncoded)

        // Check sender record to match common name of certificate
        let commonNameId = String(peer.commonName?.split(separator: ".").last ?? "")
        guard
            !self.config.testing.validateSenderRecordWithCertificate
                || senderRecord.altDsID == commonNameId || senderRecord.encDsID == commonNameId
        else {
            return .badRequest
        }

        // Check if the peer is a contact
        let matchingContacts = contactsChecker.checkIfContact(senderRecord: senderRecord)

        if !matchingContacts.isEmpty {
            peer.contactStatus = .contact(matchingContacts)
        } else {
            peer.contactStatus = .nonContact
        }

        return .ok
    }

    internal func headers(for dataSize: Int) -> [(String, String)] {
        return [
            ("Content-Type", "application/octet-stream"),
            ("Conent-Length", String(dataSize)),
            ("Connection", "keep-alive"),
            ("Accept", "*/*"),
            ("User-Agent", "AirDrop/1.0"),
            ("Accept-Language", "en-US"),
            ("Accept-Encoding", "br, gzip, deflate"),
        ]
    }
}

// MARK: - TLS Handler
extension Server: TLSHandler {

    func peer(for certificate: Data) -> ServerPeer? {
        return self.peers.first(where: { $0.peerCertificate == certificate })
    }

    func clientCertificateVerification(
        metadata: sec_protocol_metadata_t, os_trust: sec_trust_t,
        verifyCompleteCallback: sec_protocol_verify_complete_t
    ) {

        PrivateDropTLSSupport.customCertificateValidation(from: os_trust) { (result) in
            switch result {
            case .failure(let error):
                Log.error(
                    system: .server, message: "TLS verification error %@", String(describing: error)
                )
            case .success(let result):
                // Find peer for certificate

                if let peer = self.peer(for: result.certificate) {
                    self.lastPeer = peer
                } else {
                    let peer = ServerPeer(
                        commonName: result.commonName, peerCertificate: result.certificate)
                    self.peers.append(peer)
                    self.lastPeer = peer
                }

                verifyCompleteCallback(true)
            }
        }

    }

    func tlsOptions(using certConfig: PrivateDrop.Configuration.Certificates) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        let verifyQueue = DispatchQueue(label: "verifyQueue")
        let verifyBlock: sec_protocol_verify_t = {
            [weak self] metadata, osTrust, completionCallback in
            self?.clientCertificateVerification(
                metadata: metadata, os_trust: osTrust, verifyCompleteCallback: completionCallback)
        }

        // Require client certificates
        sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)

        // Add the client certificate block
        sec_protocol_options_set_verify_block(
            options.securityProtocolOptions, verifyBlock, verifyQueue)

        // TLS version
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv11)

        // Server certificate (Identity)
        guard let identity = PrivateDropTLSSupport.identity(fromPKCS12: certConfig.pkcs12Data) else {
            fatalError("Could not load certificate")
        }

        sec_protocol_options_set_local_identity(options.securityProtocolOptions, identity)

        return options

    }
}
