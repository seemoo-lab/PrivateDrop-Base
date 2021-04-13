//
//  Peer.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 20.07.20.
//

import Foundation
import NIO
import NIOHTTP1
import NIOTransportServices
import Network

public protocol PeerObserver: AnyObject {
    func peerStatusChanged(peer: Peer)
    func psiStatusChanged(peer: Peer)
    func peerErrorOccurred(error: Peer.PeerError)
}

public class Peer {

    let endpoint: NWEndpoint
    // keep a handle on current request, so we do not start multiple
    var ongoingRequest: HTTPClient?

    public internal(set) var status: Status {
        didSet {
            // notify observer about changed state
            self.observer?.peerStatusChanged(peer: self)
        }
    }

    public internal(set) var psiStatus: PSIStatus {
        didSet {
            self.observer?.psiStatusChanged(peer: self)
        }
    }

    public private(set) var name: String?
    public private(set) var model: String?
    /// The common name presented on the peer's certificate
    var certificateCommonName: String?
    /// The TLS certificate used by the peer
    var certificate: Data?

    weak var observer: PeerObserver?

    var contactsChecker: ContactsChecker?

    public enum Status: Equatable {
        /// authentication did not yet complete
        case unknown
        /// not a contact of peer
        case nonContact
        /// this is a contact of us
        case contact([String])
    }

    public enum PSIStatus: Equatable {
        /// Set if this peer does not support PSI
        case notSupported
        /// Default if PSI has not been executed
        case unknown
        /// PSI checks if client is in peer's contacts
        case notInPeersContacts
        /// Peer stopped the PSI execution, because we are not a contact of it
        case nonContact
        /// We are in peer's contacts with the ids stored here
        case contact([String])
    }

    init(
        _ endpoint: NWEndpoint, supportsPSI: Bool, observer: PeerObserver? = nil,
        contactsChecker: ContactsChecker? = nil
    ) {
        self.endpoint = endpoint
        self.status = .unknown
        self.psiStatus = supportsPSI ? .unknown : .notSupported
        self.observer = observer
        self.observer?.peerStatusChanged(peer: self)
        self.observer?.psiStatusChanged(peer: self)
        self.contactsChecker = contactsChecker
    }

    // MARK:

    func discover(using client: Client) {
        // we only call authenticate once
        assert(status == .unknown)
        // New version of PSI does not allow discover when PSI is performed. Contact check happens in PSI and /Ask
        assert(psiStatus == .unknown || psiStatus == .notSupported)

        let discoverRequestBody = DiscoverRequestBody(
            SenderRecordData: client.config.contacts.recordData)
        guard
            let discoverRequestBodyEncoded = try? PropertyListEncoder().encode(discoverRequestBody)
        else {
            Log.error(system: .client, message: "Discover failed during encoding")
            return
        }

        PrivateDrop.testDelegate?.sendingDiscoverRequest()

        client.request(
            with: self, uri: "/Discover", body: discoverRequestBodyEncoded,
            write_callback: {
                PrivateDrop.testDelegate?.actuallySendingDiscoverRequest()
            },
            callback: { (head, body) in
                guard head.status.code < 300 else {
                    Log.error(
                        system: .client, message: "Discover failed. Error returned by peer.--  %@",
                        String(describing: head))

                    if head.status == .serviceUnavailable {
                        // Connection failed. Stop the current run and return an error
                        self.status = .unknown
                        self.observer?.peerErrorOccurred(error: PeerError.connectionFailed)
                    }

                    return
                }

                PrivateDrop.testDelegate?.receivedDiscoverResponse()

                let data = body ?? Data()
                let response =
                    (try? PropertyListDecoder().decode(DiscoverResponseBody.self, from: data))
                    ?? DiscoverResponseBody()

                // store model name
                if let model = response.ReceiverModelName {
                    self.model = model
                }

                // verify record data if available
                if let recordData = response.ReceiverRecordData,
                    let contactsChecker = self.contactsChecker
                {

                    // Match the contacts
                    do {
                        try self.validateRecordDataAndCheckIfContact(
                            with: recordData, checker: contactsChecker, client: client)
                    } catch {
                        Log.error(
                            system: .client, message: "Record data could not not be verified:\n%@",
                            String(describing: error))
                        self.status = .unknown
                    }

                } else if let name = response.ReceiverComputerName {
                    // presence of computer name indicates that peer is discoverable
                    self.name = name
                    self.status = .nonContact
                }

                PrivateDrop.testDelegate?.authenticationFinished()
            })
    }

    func validateRecordDataAndCheckIfContact(
        with recordData: Data, checker: ContactsChecker, client: Client
    ) throws {

        let receiverRecord = try RecordData.from(cms: recordData)

        // Check sender record to match common name of certificate
        let commonNameId = String(self.certificateCommonName?.split(separator: ".").last ?? "")
        guard
            !client.config.testing.validateSenderRecordWithCertificate
                || receiverRecord.altDsID == commonNameId || receiverRecord.encDsID == commonNameId
        else {
            // Failed!
            Log.error(
                system: .client,
                message:
                    "The common name of the certificate does not match the id on the sender record")
            self.status = .unknown
            throw PeerError.illegalRecordData
        }

        let matchingContacts = checker.checkIfContact(senderRecord: receiverRecord)
        if matchingContacts.isEmpty == false {
            self.status = .contact(matchingContacts)
        } else {
            self.status = .nonContact
        }
    }

    /// Implements the client-side private-set-intersection (PSI) code. This code starts the first round where the client is a prover and the server a verifier
    ///
    /// The sender calls this to perform PSI with the server.
    ///  In the end, both sender and receicer will know if the other peer has them in their contacts.
    ///  Therfore, the sender can safely share the contact hashes with the receiver during /Discover.
    ///
    /// - Parameters:
    ///   - tlsHandler: A class that implements `TLSHandler` protocol can therefore, verify the TLS ertificates of the peer
    ///   - psiController: The `PSIClientController` used to run the client-side PSI
    ///
    func startPSI(using client: Client) throws {
        guard let psiController = client.psiController else {
            // PSI not available
            throw PrivateDrop.Error.psiNotAvailable
        }
        assert(psiStatus == .unknown)

        PrivateDrop.testDelegate?.sendingPSIStart()

        client.request(
            with: self, uri: "/start-psi", method: .GET,
            write_callback: { () in PrivateDrop.testDelegate?.actuallySendingPSIStart() },
            callback: { (responseHead, response) in

                self.ongoingRequest = nil

                PrivateDrop.testDelegate?.receivedPSIStartResponse()

                guard responseHead.status.code < 300 else {
                    // Error  returned
                    print("/start-psi returned error \(responseHead)")

                    if responseHead.status == .serviceUnavailable {
                        // Connection failed. Stop the current run and return an error
                        self.psiStatus = .unknown
                        self.observer?.peerErrorOccurred(error: PeerError.connectionFailed)

                    }

                    return
                }

                // If request was successful. The response is
                do {
                    let data = response ?? Data()
                    let verifierResponse = try PropertyListDecoder().decode(
                        PSIVerifierResponse.self, from: data)
                    let finisRequestData = try psiController.startPSIClient(with: verifierResponse)

                    PrivateDrop.testDelegate?.calculatedPOK()

                    try self.finishPSI(using: client, finishRequest: finisRequestData)
                } catch {
                    print("Error caught on PSI client: \(error)")
                }

            })
    }

    /// Finish PSI . This starts the second PSI round and finishes the first and the second round. In the second round the client is a verifier and ther server a prover.
    /// - Parameters:
    ///   - tlsHandler: A class that implements `TLSHandler` protocol can therefore, verify the TLS ertificates of the peer
    ///   - psiController: The `PSIClientController` used to run the client-side PSI
    ///   - finishRequest: The request body content that should be sent to the server. Generated in `startPSI(...)`
    func finishPSI(using client: Client, finishRequest: PSIFinisRequest) throws {
        guard client.psiController != nil else {
            // PSI not available
            throw PrivateDrop.Error.psiNotAvailable
        }

        assert(psiStatus == .unknown)
        let body = try? PropertyListEncoder().encode(finishRequest)

        PrivateDrop.testDelegate?.sendingPSIFinish()

        client.request(
            with: self, uri: "/finish-psi", method: .POST,
            head: nil, body: body,
            write_callback: { () in PrivateDrop.testDelegate?.actuallySendingPSIFinish() },
            callback: { [weak self] (responseHead, response) in
                self?.handleFinisPSI(
                    client: client, finishRequest: finishRequest, responseHead: responseHead,
                    response: response)
            })
    }

    fileprivate func handleFinisPSI(
        client: Client, finishRequest: PSIFinisRequest, responseHead: HTTPResponseHead,
        response: Data?
    ) {

        PrivateDrop.testDelegate?.receivedPSIFinish()

        guard responseHead.status.code < 300 else {
            // Error  returned
            print("/finish-psi returned error \(responseHead)")
            if responseHead.status == .unauthorized {
                self.psiStatus = .notInPeersContacts
            }

            if responseHead.status == .serviceUnavailable {
                // Connection failed. Stop the current run and return an error
                self.psiStatus = .unknown
                self.observer?.peerErrorOccurred(error: PeerError.connectionFailed)

            }

            return
        }

        do {
            guard let psiController = client.psiController else {
                throw PrivateDrop.Error.psiNotAvailable
            }
            let data = response ?? Data()
            let finishResponse = try PropertyListDecoder().decode(
                PSIFinishResponse.self, from: data)

            let matchingContact = try psiController.finishPSIClient(
                with: finishResponse.proverResponse)
            self.psiStatus = .contact(matchingContact)

            PrivateDrop.testDelegate?.PSICompleted(
                peerContacts: finishResponse.proverResponse.u.count,
                peerIds: finishRequest.prover.z.count)

            // Check Receiver Record Data
            if let recordData = finishResponse.ReceiverRecordData,
                recordData.isEmpty == false,
                let contactsChecker = self.contactsChecker
            {
                // A new PSI version integrates the record data in the finish response. This can be used to identify if peer is a contact.
                do {
                    try self.validateRecordDataAndCheckIfContact(
                        with: recordData, checker: contactsChecker, client: client)
                } catch {
                    Log.error(
                        system: .client, message: "Error caught on record data validation %@",
                        String(describing: error))
                    self.status = .unknown
                }
            }

        } catch {
            if let psiError = error as? PSIController.Error {
                switch psiError {
                case .noContactMatch:
                    self.psiStatus = .nonContact
                default:
                    self.psiStatus = .unknown
                    assert(false, "Should not reach this state PSI not initialized properly")
                }
            } else {
                Log.error(
                    system: .client, message: "Error caught on PSI client %@",
                    String(describing: error))

            }
        }

        PrivateDrop.testDelegate?.authenticationFinished()
    }

    public func connect() -> Connection? {
        if status == .unknown {
            return nil
        } else {
            return Connection(peer: self)
        }
    }

    public enum PeerError: Error {
        case connectionFailed
        case illegalRecordData
    }

}
