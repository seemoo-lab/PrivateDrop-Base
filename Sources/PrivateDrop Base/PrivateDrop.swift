//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Crypto
import Foundation
import PSI

/// Delegate to handle receving files. Used by the PrivateDropServer when it receives files or requests
public protocol PrivateDropReceiverDelegate: AnyObject {
    /// The receicer has been discovered by a sender.
    func discovered(with status: Peer.Status)

    /// Received a file or directory and it has been saved at the given URL
    func receivedFiles(at: URL)

    /// Received an ask request
    func receivedAsk(
        request: AskRequestBody, matchingContactId: [String]?,
        userResponse: @escaping (Bool) -> Void)

    /// Stopped the execution because of an error that occurred
    func errorOccurred(error: Error)

    /// Called when the server started and the Bonjour started
    func privateDropReady()
}

/// Delegate for sender events.
public protocol PrivateDropSenderDelegate: AnyObject {
    /// Found a peer using Bonjour. Before a Peer can receive a file use `detectIfContact`
    func found(peer: Peer)

    // Finished the PSI protocol with the peer
    func finishedPSI(with peer: Peer)

    /// Contact checking finished for peer.
    func contactCheckCompleted(receiver: Peer)

    /// Peer declined the file by responding denying the ask request
    func peerDeclinedFile()

    /// The file has finished sending
    func finishedSending()

    /// Stopped the execution because of an error that occurred
    func errorOccurred(error: Error)

}

/// PrivateDrop is the only class that needs to be accessed when performing the **PrivateDrop** or **AirDrop** protocol
public class PrivateDrop {
    /// PrivateDrop Server handles receiving files
    private(set) var server: Server
    /// Client handles sending files
    private(set) var client: Client
    /// Advertiser handles service publication on Bonjour
    private(set) var advertiser = Advertiser()
    /// The contacts checker checks if the any contact matches the hashes in the Discover request
    private(set) var contactsChecker: ContactsChecker

    /// Delegate for receiving files. Can be a different class then the sender delegate
    public var receiverDelegate: PrivateDropReceiverDelegate? {
        didSet {
            self.server.receiverDelegate = receiverDelegate
        }
    }

    /// This delegate can be set for testing and evaluation. It reports many itermediate steps
    public static var testDelegate: PrivateDropTestDelegate?

    /// Delegate for sending files.
    public weak var senderDelegate: PrivateDropSenderDelegate?
    /// The current configuration determines how the communication is secured, which contacts are known and if the receiver uses a contacts only scheme.
    public var configuration: PrivateDrop.Configuration

    let psiController: PSIController

    /// Initialize a new PrivateDrop instance with a configuration
    /// - Parameter configuration: The current PrivateDrop configuration
    public init(with configuration: Configuration) {
        self.configuration = configuration
        self.contactsChecker = ContactsChecker(ownContactIds: configuration.contacts.contacts)
        self.psiController = PSIController(contactsConfig: configuration.contacts)!
        self.server = Server(
            config: configuration, psiController: self.psiController,
            contactsChecker: self.contactsChecker)
        self.client = Client(
            config: configuration, psiController: self.psiController,
            contactsChecker: self.contactsChecker)
        self.client.observer = self
    }

    /// PrivateDrop uses several values that may need to be pre-computed to increase the speed of operation.
    ///
    /// This function will pre-compute the PSI U_i values and the contact hashes for Discover
    /// - Parameter finished: Called when the precomputation is done
    public func precomputeContactValues(finished: @escaping () -> Void) {
        guard
            !(self.client.psiController?.valuesCached ?? true)
                || !(self.server.psi?.valuesCached ?? true)
        else {
            finished()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {

            var durationU: TimeInterval?
            if self.configuration.general.supportsPrivateDrop {
                let date = Date()
                _ = self.psiController.prover.generateU()
                durationU = -date.timeIntervalSinceNow
            }

            // Hashed contacts
            let date = Date()
            self.contactsChecker.computeHashes(for: self.configuration.contacts)
            let durationHash = -date.timeIntervalSinceNow

            DispatchQueue.main.async {
                finished()
                if let durationU = durationU {
                    PrivateDrop.testDelegate?.precomputeUDuration(time: durationU)
                }

                PrivateDrop.testDelegate?.precomputeContactHashesDuration(time: durationHash)
            }
        }
    }

    // MARK: - Receiving files

    /// Start the PrivateDrop Server and advertise its address using Bonjour
    /// - Parameters:
    ///   - timeout: When to stop the server. By default it stays alive until stopped
    ///   - port: The port on which the HTTP server should start
    /// - Throws: Errors when the setip fails .
    public func startListening(timeout: TimeInterval? = nil, port: Int = 8443) throws {

        try self.server.startServer(
            port: port,
            completion: { (_, port) in
                // Server started.

                // Delay advertising, because server setup needs about 1s
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.advertiser.advertiseAirDrop(
                        configuration: self.configuration, serverPort: Int32(self.server.port))

                    self.receiverDelegate?.privateDropReady()
                }
            })

        if let timeout = timeout {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                self.stopListening()
            }
        }
    }

    /// Stop listening for incoming files / connections. Stops the Bonjour publication and the server
    public func stopListening() {
        self.server.stopServer()
        self.advertiser.stopAdvertisingAirDrop()
    }

    // MARK: - Sending files

    /// Browse for AirDrop/PrivateDrop enabled devices on the local (AWDL) network.
    /// - Parameters:
    ///   - timeout: Timeout when to stop the browsing. If nil, the browsing continues until stopped manually
    ///   - privateDropOnly: If true only peers with PrivateDrop support will be reported
    public func browse(timeout: TimeInterval? = nil, privateDropOnly psiOnly: Bool) {
        self.client.start(psiOnly: psiOnly)

        if let timeout = timeout {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                self.client.stop()
            }
        }
    }

    /// Stop browsing manually
    public func stopBrowsing() {
        self.client.stop()
    }

    /// Detect if the found peer is a contact or not.
    /// If the peer supports PSI it can be used to privately detect if the you are in the peers contacts and if the peer is in your contacts.
    /// - Parameters:
    ///   - peer: Peer that has been found with Bonjour
    ///   - usePSI: If true, the PrivateDrop PSI protocol will be performed. Only possible, if the peer supports PSI
    public func detectContact(for peer: Peer, usePSI: Bool) {
        // Start with PSI / Discover

        if peer.psiStatus == .notSupported || !usePSI {
            peer.discover(using: self.client)
        } else {
            // Start PSI
            do {
                try peer.startPSI(using: self.client)
            } catch {
                self.senderDelegate?.errorOccurred(error: error)
            }

        }
    }

    /// Send a file to the given peer. The file can be a directory that will be archived and sent
    /// - Parameters:
    ///   - url: File URL to the directory / file that should be sent
    ///   - peer: Peer that should receive the file
    /// - Throws: Throws an error if the peer is in a invalid state
    public func sendFile(at url: URL, to peer: Peer) throws {
        guard peer.status != .unknown else {
            throw Error.invalidState(
                description:
                    "You must check if peer is one of your contacts first. Even if contacts only is off."
            )
        }

        let connection = peer.connect()
        connection?.delegate = self
        try connection?.send(file: url, using: self.client)
    }

    public func discover(peer: Peer) {
        peer.discover(using: self.client)
    }

}

extension PrivateDrop: PeerObserver {

    public func peerErrorOccurred(error: Peer.PeerError) {
        // Report any errors when communicating with the peer
        self.senderDelegate?.errorOccurred(error: error)
    }

    public func peerStatusChanged(peer: Peer) {
        // Report status changes to the sender delegate
        switch peer.status {
        case .nonContact, .contact:
            self.senderDelegate?.contactCheckCompleted(receiver: peer)
        case .unknown:
            self.senderDelegate?.found(peer: peer)

        }
    }

    public func psiStatusChanged(peer: Peer) {
        // Report changes about the PSI protocol

        switch peer.psiStatus {
        case .contact, .nonContact, .notInPeersContacts:
            self.senderDelegate?.finishedPSI(with: peer)
        default:
            break
        }
    }

}

extension PrivateDrop: ConnectionDelegate {
    public func notify(_ connection: Connection, is status: ConnectionStatus) {
        switch status {
        case .done:
            self.senderDelegate?.finishedSending()
        case .abort(let reason):
            switch reason {
            case .denied:
                self.senderDelegate?.peerDeclinedFile()
            case .timeout:
                self.senderDelegate?.errorOccurred(error: Error.timeout)
            case .canceled:
                print("Canceled sending")
            }
        default:
            Log.debug(system: .client, message: "Sending status: %@", String(describing: status))
        }
    }
}

extension PrivateDrop {
    public enum Error: Swift.Error {
        case invalidState(description: String)
        case psiNotAvailable
        case timeout
    }
}

public struct PrivatePSIValues: Codable {
    let a: [Data]
    let hashes: [Data]
    public let ids: [String]
}
