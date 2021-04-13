//
//  ServerRoutes.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 27.10.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

import Foundation
import Libarchive
import NIOHTTP1
import NIOSSL
import NIOTransportServices
import PSI

extension Server {

    /// Defines the routes that are supported by the server. Every route has a function that is called if a client sends data to it.
    var routes: [HTTPRoute] {
        [
            HTTPRoute(
                method: .POST, uri: "/Discover",
                call: { [weak self] request, server in
                    self?.handleDiscover(request: request, server: server)
                }),
            HTTPRoute(
                method: .POST, uri: "/Ask",
                call: { [weak self] request, server in
                    self?.handleAsk(request: request, server: server)
                }),
            HTTPRoute(
                method: .POST, uri: "/Upload",
                call: { [weak self] request, server in
                    self?.handleUpload(request: request, server: server)
                }),
            HTTPRoute(
                method: .GET, uri: "/start-psi",
                call: { [weak self] request, server in
                    self?.handleStartPSI(request: request, server: server)
                }),
            HTTPRoute(
                method: .POST, uri: "/finish-psi",
                call: { [weak self] request, server in
                    self?.handleFinishPSI(request: request, server: server)
                }),
        ]
    }

    /// Handles the AirDrop `/Discover` request
    ///
    /// This request checks if both peers know each other. They will exchange hashed contact identifiers to identify each other. This metod is called by `HTTPServer`
    ///
    /// - Parameters:
    ///   - request: The current request.
    ///   - server: The HTTPServer that received the request
    func handleDiscover(request: HTTP1Request, server: HTTP1Server) {
        PrivateDrop.testDelegate?.discoverReceived()
        guard let body = request.bodyData,
            let discoverBody = try? PropertyListDecoder().decode(
                DiscoverRequestBody.self, from: body)
        else {
            server.sendResponse(with: request.context, status: .badRequest)
            return
        }

        do {
            let currentPeer = self.lastPeer
            currentPeer?.address = request.context.remoteAddress

            // Handle Sender Record
            if let senderRecordEncoded = discoverBody.SenderRecordData,
                senderRecordEncoded.isEmpty == false,
                let contactsChecker = self.contactsChecker,
                let peer = currentPeer
            {

                let status = try self.performContactCheck(
                    with: senderRecordEncoded, peer: peer, contactsChecker: contactsChecker)

                guard status == .ok else {
                    server.sendResponse(with: request.context, status: status)
                    return
                }

            } else if self.config.contacts.contactsOnly {
                // No Sender Record == no contact.
                server.sendResponse(with: request.context, status: .unauthorized)
            }

            DispatchQueue.main.async {
                let status = currentPeer?.contactStatus ?? .unknown
                self.receiverDelegate?.discovered(with: status)
            }

            let mediaCapabilities = [
                "Version": 1
            ]
            let mediaCapabilitiesData = try JSONSerialization.data(
                withJSONObject: mediaCapabilities)

            let responseBody = DiscoverResponseBody(
                ReceiverComputerName: self.config.general.computerName,
                ReceiverMediaCapabilities: mediaCapabilitiesData,
                ReceiverModelName: self.config.general.modelName,
                ReceiverRecordData: self.config.contacts.recordData)

            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(responseBody)

            let headers = HTTPHeaders(self.headers(for: data.count))

            // Send the response
            server.sendResponse(with: request.context, status: .ok, headers: headers, body: data)
        } catch {
            Log.error(system: .server, message: "Discover failed %@", String(describing: error))
            server.sendResponse(with: request.context, status: .internalServerError)
        }

        PrivateDrop.testDelegate?.discoverResponseSent()
        PrivateDrop.testDelegate?.authenticationFinished()
    }

    /// Handles incoming /Ask requests. They have to be answered by a user if they accept the inoming file.
    /// If the user confirms it the server will send back a 200-OK and therefore, confirm that it wants to receive a file.
    /// - Parameters:
    ///   - request: Incoming HTTP request
    ///   - server: The NIO Server handling the request
    func handleAsk(request: HTTP1Request, server: HTTP1Server) {
        guard let body = request.bodyData else {
            server.sendResponse(with: request.context, status: .badRequest)
            return
        }

        do {
            let askBody = try PropertyListDecoder().decode(AskRequestBody.self, from: body)
            // Log.debug(system: .server, message: "Received ask request %@", String(describing: askBody))

            // Receiver delegate is needed, because we want the user to validate if he/she wants to accept the incoming file
            assert(self.receiverDelegate != nil)
            guard let receiverDelegate = self.receiverDelegate else {
                Log.error(
                    system: .server, message: "No receiver delegate in use. %@:%d", #file, #line)
                server.sendResponse(with: request.context, status: .notAcceptable)
                return
            }

            let response: (Bool) -> Void = { accepted in
                if accepted {
                    let askResponse = AskResponseBody(
                        ReceiverComputerName: self.config.general.computerName,
                        ReceiverModelName: self.config.general.modelName)
                    do {
                        let data = try PropertyListEncoder().encode(askResponse)

                        let headers = HTTPHeaders(self.headers(for: data.count))
                        server.sendResponse(
                            with: request.context, status: .ok, headers: headers, body: data)
                    } catch {
                        server.sendResponse(with: request.context, status: .internalServerError)
                    }

                } else {
                    server.sendResponse(with: request.context, status: .notAcceptable)
                }
            }

            if let recordDataEncoded = askBody.SenderRecordData,
                recordDataEncoded.isEmpty == false,
                let contactsChecker = self.contactsChecker,
                let peer = self.lastPeer
            {
                // Validate the sender record (again, because it might have changed).
                let status = try self.performContactCheck(
                    with: recordDataEncoded, peer: peer, contactsChecker: contactsChecker)

                guard status == .ok else {
                    server.sendResponse(with: request.context, status: status)
                    return
                }

                if case .contact(let contactId) = peer.contactStatus {
                    receiverDelegate.receivedAsk(
                        request: askBody, matchingContactId: contactId, userResponse: response)
                } else {
                    receiverDelegate.receivedAsk(
                        request: askBody, matchingContactId: nil, userResponse: response)
                }
            } else {
                receiverDelegate.receivedAsk(
                    request: askBody, matchingContactId: nil, userResponse: response)
            }

        } catch {
            server.sendResponse(with: request.context, status: .internalServerError)
        }

    }

    func handleUpload(request: HTTP1Request, server: HTTP1Server) {

        guard request.head.headers.first(name: "content-type")?.lowercased() == "application/x-cpio"
        else {
            // Cannot process content
            server.sendResponse(with: request.context, status: .unprocessableEntity)
            return
        }

        //        if request.head.headers.first(name: "expect")?.lowercased() == "100-continue" {
        //            //Respond with continue
        //            let headers = HTTPHeaders([("Content-Length", "0")])
        //            server.sendResponse(with: request.context, status: .continue, headers: headers, body: nil)
        //        }

        // Check if using chunked encoding
        guard request.head.headers.first(name: "transfer-encoding")?.lowercased() == "chunked"
        else {
            // Not supporting chunked encoding
            let headers = HTTPHeaders([
                ("Transfer-Encoding", "Chunked"), ("Content-Length", "0"), ("Connection", "close"),
            ])
            server.sendResponse(
                with: request.context, status: .badRequest, headers: headers, body: nil)
            return
        }

        // Parse chunked encoding
        guard let uploadBody = request.bodyData else {
            return
        }

        #if os(macOS)
            let searchPathDirectory: FileManager.SearchPathDirectory = .downloadsDirectory
        #else
            let searchPathDirectory: FileManager.SearchPathDirectory = .documentDirectory
        #endif

        do {
            // Write content to file
            let fileURL: URL = FileManager.default.urls(
                for: searchPathDirectory, in: .userDomainMask
            )
            .first!.appendingPathComponent("upload.dat")
            try uploadBody.write(to: fileURL)
            // Extract the archived content
            let url = try Libarchive.readCPIO(cpio: uploadBody)
            Log.debug(system: .server, message: "Files are at %@", url.absoluteString)
            DispatchQueue.main.async { self.receiverDelegate?.receivedFiles(at: url) }
            if let receiverTest = PrivateDrop.testDelegate {
                receiverTest.fileReceived(size: uploadBody.count)
            }

        } catch {
            server.sendResponse(with: request.context, status: .internalServerError)
            return
        }

        server.sendResponse(with: request.context, status: .ok)

    }

    // MARK: PSI

    /// Performs private-set-intersection (PSI) with the client. A PSIController is generated to perform the PSI protocol.
    /// If started the server awaits two consequitive requests.
    /// One to /start-psi and one to /finish-psi from the same client. Otherwise, the protocol will fail.
    ///
    /// PSI allows the server to know if the it is in the client's contact list.
    /// HTTPServer calls this function with a request and a server used for responding
    ///
    /// - Parameters:
    ///   - request: The current request.
    ///   - server: The HTTPServer that received the request
    func handleStartPSI(request: HTTP1Request, server: HTTP1Server) {
        guard let psiController = self.psi else {
            // PSI not available
            server.sendResponse(with: request.context, status: .notFound)
            return
        }

        do {
            PrivateDrop.testDelegate?.psiStartReceived()
            let response = try psiController.startPSIServer()
            let respData = try PropertyListEncoder().encode(response)
            let headers = HTTPHeaders(self.headers(for: respData.count))
            server.sendResponse(
                with: request.context, status: .ok, headers: headers, body: respData)
        } catch {
            server.sendResponse(with: request.context, status: .internalServerError)
        }
        PrivateDrop.testDelegate?.psiStartSentResponseSent()
    }

    /// Finishes PSI by performing the set intersection with the client contacts and responding to the client with the second round in which the server behaves as a prover.
    ///
    /// HTTPServer calls this function with a request and a server used for responding
    ///
    /// - Parameters:
    ///   - request: The current request.
    ///   - server: The HTTPServer that received the request
    func handleFinishPSI(request: HTTP1Request, server: HTTP1Server) {
        PrivateDrop.testDelegate?.psiFinishReceived()

        guard let psiController = self.psi else {
            // PSI not available
            server.sendResponse(with: request.context, status: .notFound)
            return
        }
        guard let buf = request.bodyData,
            let finishRequest = try? PropertyListDecoder().decode(PSIFinisRequest.self, from: buf)
        else {
            server.sendResponse(with: request.context, status: .badRequest)
            return
        }

        do {
            let proverResponse = try psiController.finishPSIServer(with: finishRequest)
            let finishResponse = PSIFinishResponse(
                proverResponse: proverResponse, ReceiverRecordData: self.config.contacts.recordData)

            PrivateDrop.testDelegate?.PSICompleted(
                peerContacts: finishRequest.prover.u.count, peerIds: proverResponse.z.count)

            let respData = try PropertyListEncoder().encode(finishResponse)
            let headers = HTTPHeaders(self.headers(for: respData.count))
            server.sendResponse(
                with: request.context, status: .ok, headers: headers, body: respData)

        } catch {
            // Handle thrown errors

            if let verifierError = error as? Verifier.Error {
                switch verifierError {
                case .verificationFailed:
                    server.sendResponse(with: request.context, status: .unauthorized)
                case .notInitialized:
                    server.sendResponse(with: request.context, status: .internalServerError)
                }

                return
            }

            if let psiError = error as? PSIController.Error {
                switch psiError {
                case .noContactMatch:
                    server.sendResponse(with: request.context, status: .unauthorized)
                case .stateError:
                    server.sendResponse(with: request.context, status: .internalServerError)
                }
                return
            }

            server.sendResponse(with: request.context, status: .internalServerError)

        }
        PrivateDrop.testDelegate?.psiFinishResponseSent()
        PrivateDrop.testDelegate?.authenticationFinished()
    }
}
