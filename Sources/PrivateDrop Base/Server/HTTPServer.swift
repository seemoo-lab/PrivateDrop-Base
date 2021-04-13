//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 04.06.20.
//

#if canImport(Network)
    import NIO
    import NIOSSL
    import NIOTransportServices
    import NIOHTTP1
    import Network
    import Foundation

    class HTTP1Request {
        let context: ChannelHandlerContext
        let head: HTTPRequestHead
        var bodyData: Data?
        var endHead: HTTPHeaders?

        init(context: ChannelHandlerContext, head: HTTPRequestHead) {
            self.context = context
            self.head = head
        }

        static func == (lhs: HTTP1Request, context: ChannelHandlerContext) -> Bool {
            return lhs.context.remoteAddress == context.remoteAddress
        }
    }

    struct HTTPRoute {
        let method: HTTPMethod
        let uri: String
        let call: (_ request: HTTP1Request, _ server: HTTP1Server) -> Void
    }

    protocol HTTPInboundDelegate: AnyObject {
        func received(request: HTTP1Request)
    }

    final class HTTPChannelHandler: ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart

        /// All current requests. Stored to fetch header and body seperately, but perform one operation on both
        private var currentRequests = [HTTP1Request]()

        weak var delegate: HTTPInboundDelegate?

        init() {
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let part = self.unwrapInboundIn(data)

            switch part {
            case .head(let headers):
                self.currentRequests.append(HTTP1Request(context: context, head: headers))

            case .body(let body):

                guard let request = self.currentRequests.first(where: { $0 == context }) else {
                    return
                }

                // Just append the data
                if request.bodyData == nil {
                    request.bodyData = Data(body.readableBytesView)
                } else {
                    request.bodyData! += Data(body.readableBytesView)
                }

            case .end(let headers):

                if let request = self.currentRequests.first(where: { $0 == context }) {

                    request.endHead = headers
                    self.delegate?.received(request: request)
                }

            }
        }

        func sendResponse(
            with context: ChannelHandlerContext, status: HTTPResponseStatus,
            headers: HTTPHeaders? = nil,
            body: Data? = nil
        ) {

            var httpHeaders: HTTPHeaders
            if let o = headers {
                httpHeaders = o
            } else {
                httpHeaders = HTTPHeaders([
                    ("content-length", body == nil ? "0" : String(body!.count))
                ])
            }

            var byteBuffer: ByteBuffer?
            if let data = body {
                byteBuffer = context.channel.allocator.buffer(capacity: data.count)
                byteBuffer?.writeBytes(data)
            }

            // Send header
            let responseHead = HTTPResponseHead(
                version: .init(major: 1, minor: 1), status: status, headers: httpHeaders)
            context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)

            // Send body
            if let byteBuffer = byteBuffer {
                context.write(self.wrapOutboundOut(.body(.byteBuffer(byteBuffer))), promise: nil)
            }

            // Send end
            context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
            context.flush()

            // Remove request from array
            if let firstIndex = self.currentRequests.firstIndex(where: { $0 == context }) {
                self.currentRequests.remove(at: firstIndex)
            }
        }

    }

    @available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *)
    final class HTTP1Server: HTTPInboundDelegate {

        private var channel: Channel?
        private var group: EventLoopGroup?

        /// All available routes that the server can handle
        private var routes: [HTTPRoute] = []

        internal weak var tlsHandler: TLSHandler?

        public private(set) var port: Int = 8888

        var channelHandler: HTTPChannelHandler?

        init(tlsHandler: TLSHandler) {
            self.tlsHandler = tlsHandler
            // Add default routes
            self.setDefaultRoutes()

        }

        func setDefaultRoutes() {
            let getHelloWorld = HTTPRoute(method: HTTPMethod.GET, uri: "/") { (request, server) in

                let body = "Hello World".data(using: .utf8)!

                let headers = HTTPHeaders([
                    ("Content-Type", "text/plain"),
                    ("Content-Length", "\(body.count)"),
                ])

                server.sendResponse(
                    with: request.context, status: .ok, headers: headers, body: body)
            }

            let postEcho = HTTPRoute(method: HTTPMethod.POST, uri: "/") { (request, server) in

                var responseData: Data?
                responseData = request.bodyData

                server.sendResponse(
                    with: request.context, status: .ok, headers: request.head.headers,
                    body: responseData)
            }

            self.routes.append(contentsOf: [getHelloWorld, postEcho])
        }

        func received(request: HTTP1Request) {
            self.handleRequest(request: request)
        }

        func handleRequest(request: HTTP1Request) {

            // Log.debug(system: .server, message: "Request with\n%@ ", String(describing: request.head))

            if let route = self.routes.first(where: {
                $0.method == request.head.method && $0.uri == request.head.uri
            }) {
                route.call(request, self)
            } else {
                self.notFound(context: request.context)
            }
        }

        private func notFound(context: ChannelHandlerContext) {
            // 404
            let responseHeaders = HTTPHeaders([
                ("server", "nio-transport-services"), ("content-length", "0"),
            ])
            self.sendResponse(with: context, status: .notFound, headers: responseHeaders)
        }

        func sendResponse(
            with context: ChannelHandlerContext, status: HTTPResponseStatus,
            headers: HTTPHeaders? = nil,
            body: Data? = nil
        ) {

            self.channelHandler?.sendResponse(
                with: context, status: status, headers: headers, body: body)
        }

        // MARK: - Start

        /// Starts a new HTTPServer bound to the specified port and using the certificates supplied as TLS certificates
        /// - Parameters:
        ///   - port: HTTP Port to use
        ///   - certificates: TLS Certificates for the server
        ///   - completion: Called when the  channel bound to the specified address and port
        func start(
            port: Int, certificates: PrivateDrop.Configuration.Certificates,
            completion: @escaping (_ host: String, _ port: Int) -> Void
        ) {
            let group = NIOTSEventLoopGroup()
            self.channelHandler = HTTPChannelHandler()
            self.channelHandler?.delegate = self

            let channel: Channel
            do {

                channel = try NIOTSListenerBootstrap(group: group)
                    // Client certificate verification
                    .tlsOptions(self.tlsHandler!.tlsOptions(using: certificates))
                    .serverChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
                    .serverChannelOption(NIOTSChannelOptions.enablePeerToPeer, value: true)
                    .childChannelInitializer({ (channel) in

                        channel.pipeline.configureHTTPServerPipeline(
                            position: .first, withPipeliningAssistance: true,
                            withServerUpgrade: .none,
                            withErrorHandling: true
                        )
                        .flatMap {
                            channel.pipeline.addHandler(self.channelHandler!)
                        }
                    })
                    .bind(host: "::", port: port).wait()

                self.port = port

            } catch {
                Log.error(
                    system: .server, message: "Could not bind Server:\n%@",
                    String(describing: error))
                // Increase port number
                self.start(port: port + 1, certificates: certificates, completion: completion)
                return
            }

            // swiftlint:disable force_try
            defer {
                try! group.syncShutdownGracefully()
            }

            self.channel = channel

            print("Server listening on \(channel.localAddress!)")
            completion("::", port)
            // Wait for the request to complete
            try! channel.closeFuture.wait()
        }

        func shutdown() {

            group?.shutdownGracefully({ (error) in
                guard let error = error else { return }
                Log.error(
                    system: .server, message: "Server shutdown failed %@", String(describing: error)
                )
            })

            //        self.channel?.close(mode: .all)
            //            .whenFailure({ (error) in
            //                Log.error(system: .server, message: "Channel shutdwn failed %@", String(describing: error))
            //            })

            self.channel?.pipeline.close(mode: .all)
                .whenFailure({ (error) in
                    Log.error(
                        system: .server, message: "Channel Pipeline shutdwn failed %@",
                        String(describing: error))
                })

            self.group = nil
            self.channel = nil
            self.channelHandler?.delegate = nil
            self.channelHandler = nil
        }

        func addRoutes(routes: [HTTPRoute]) {
            self.routes.append(contentsOf: routes)
        }

    }
#endif
