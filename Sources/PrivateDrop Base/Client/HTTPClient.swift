//
//  HTTPClient.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 20.07.20.
//

import Foundation
import NIO
import NIOHTTP1
import NIOTransportServices
import Network

class HTTPClient {

    var channel: EventLoopFuture<Channel>?
    weak var peer: Peer?
    let certificates: PrivateDrop.Configuration.Certificates?

    init(
        endpoint: NWEndpoint, uri: String, certificates: PrivateDrop.Configuration.Certificates,
        head: [(String, String)]? = nil, body: Data? = nil,
        method: HTTPMethod = .POST, callback: ((HTTPResponseHead, Data?) -> Void)?
    ) {
        self.certificates = certificates
        self.peer = nil

        let channel = NIOTSConnectionBootstrap(group: group)
            .connectTimeout(.hours(1))
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(NIOTSChannelOptions.enablePeerToPeer, value: true)
            .tlsOptions(self.tlsOptions(using: certificates))
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandler(
                        HTTPClientHandler(
                            uri: uri, head: head, body: body, method: method, callback: callback))
                }
            }
            .connect(endpoint: endpoint)
        self.channel = channel

        _ = self.channel?.flatMapErrorThrowing { (error) -> Channel in
            Log.error(
                system: .client, message: "Client channel failed with error %@",
                String(describing: error))
            callback?(
                HTTPResponseHead(
                    version: HTTPVersion(major: 1, minor: 1), status: .serviceUnavailable), nil
            )
            throw error
        }
    }

    init(
        with peer: Peer, uri: String, method: HTTPMethod = .POST,
        certificates: PrivateDrop.Configuration.Certificates, head: [(String, String)]? = nil,
        body: Data? = nil, write_callback: (() -> Void)?,
        callback: ((HTTPResponseHead, Data?) -> Void)?
    ) {

        self.peer = peer
        self.certificates = certificates

        let channel = NIOTSConnectionBootstrap(group: group)
            .connectTimeout(.hours(1))
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(NIOTSChannelOptions.enablePeerToPeer, value: true)
            .tlsOptions(self.tlsOptions(using: certificates))
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers().flatMap {
                    channel.pipeline.addHandler(
                        HTTPClientHandler(
                            uri: uri, head: head, body: body, method: method,
                            write_callback: write_callback,
                            callback: callback))
                }
            }
            .connect(endpoint: peer.endpoint)
        self.channel = channel

        _ = self.channel?.flatMapErrorThrowing { (error) -> Channel in
            Log.error(
                system: .client, message: "Client channel failed with error %@",
                String(describing: error))
            callback?(
                HTTPResponseHead(
                    version: HTTPVersion(major: 1, minor: 1), status: .serviceUnavailable), nil
            )
            throw error
        }
    }

    // swiftlint:disable nesting
    final class HTTPClientHandler: ChannelInboundHandler {
        typealias OutboundOut = HTTPClientRequestPart
        typealias InboundIn = HTTPClientResponsePart

        let uri: String
        let body: Data?
        let head: [(String, String)]?
        var responseHeader: HTTPResponseHead?
        //        var responseBody: ByteBuffer?
        var responseBody: Data?
        let callback: ((HTTPResponseHead, Data?) -> Void)?
        let write_callback: (() -> Void)?
        let method: HTTPMethod

        init(
            uri: String, head: [(String, String)]? = nil, body: Data? = nil,
            method: HTTPMethod = .POST, write_callback: (() -> Void)? = nil,
            callback: ((HTTPResponseHead, Data?) -> Void)? = nil
        ) {
            self.uri = uri
            self.head = head
            self.body = body
            self.responseHeader = nil
            self.responseBody = nil
            self.callback = callback
            self.write_callback = write_callback
            self.method = method
        }

        private func getDefaultHeaders() -> [(String, String)] {
            return [
                ("Content-Type", "application/octet-stream"),
                ("Connection", "keep-alive"),
                ("Accept", "*"),
                ("User-Agent", "AirDrop/1.0"),
                ("Accept-Language", "en-us"),
                ("Accept-Encoding", "br, gzip, deflate"),
            ]
        }

        func channelActive(context: ChannelHandlerContext) {
            self.write_callback?()
            var head = HTTPRequestHead(
                version: .init(major: 1, minor: 1), method: self.method, uri: self.uri)
            head.headers.add(contentsOf: getDefaultHeaders())

            if let headers = self.head {
                for (name, value) in headers {
                    head.headers.replaceOrAdd(name: name, value: value)
                }
            }
            if !head.headers.contains(name: "Transfer-Encoding") {
                head.headers.add(name: "Content-Length", value: "\(body?.count ?? 0)")
            }

            context.write(self.wrapOutboundOut(.head(head)), promise: nil)

            if let body = self.body {
                var buffer = context.channel.allocator.buffer(capacity: body.count)
                buffer.writeBytes(body)
                context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let part = self.unwrapInboundIn(data)

            switch part {
            case .head(let head):
                self.responseHeader = head
            case .body(let body):

                // Just append the data
                if responseBody == nil {
                    responseBody = Data(body.readableBytesView)
                } else {
                    responseBody! += Data(body.readableBytesView)
                }
            case .end:
                if responseHeader != nil {
                    callback?(responseHeader!, responseBody)
                }
                context.close(promise: nil)
            }
        }

        static func printResponseHead(_ head: HTTPResponseHead) {
            print(
                "HTTP/\(head.version.major).\(head.version.minor) \(head.status.code) \(head.status.reasonPhrase)"
            )
            for (name, value) in head.headers {
                print("\(name): \(value)")
            }
        }
    }

}

extension HTTPClient: TLSHandler {
    func customCertificateVerification(
        metadata: sec_protocol_metadata_t, os_trust: sec_trust_t,
        verifyCompleteCallback: sec_protocol_verify_complete_t
    ) {
        PrivateDropTLSSupport.customCertificateValidation(from: os_trust) { [weak self] (result) in
            switch result {
            case .failure(let error):
                Log.error(
                    system: .client, message: "TLS verification error %@", String(describing: error)
                )
                verifyCompleteCallback(false)
            case .success(let result):
                self?.peer?.certificateCommonName = result.commonName
                self?.peer?.certificate = result.certificate
                verifyCompleteCallback(true)
            }
        }
    }

    func tlsOptions(using certConfig: PrivateDrop.Configuration.Certificates) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()

        let verifyBlock: sec_protocol_verify_t = {
            [weak self] metadata, osTrust, completionCallback in
            self?.customCertificateVerification(
                metadata: metadata, os_trust: osTrust, verifyCompleteCallback: completionCallback)
        }

        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv11)

        let queue = DispatchQueue(label: "verify queue")
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, verifyBlock, queue)

        // Use client certificates
        guard let identity = PrivateDropTLSSupport.identity(fromPKCS12: certConfig.pkcs12Data) else {
            fatalError("Could not load certificate")
        }

        sec_protocol_options_set_local_identity(options.securityProtocolOptions, identity)

        return options
    }

}
