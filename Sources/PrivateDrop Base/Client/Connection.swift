//
//  Connection.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 20.07.20.
//

import Foundation
import Libarchive
import NIO
import NIOHTTP1
import NIOTransportServices
import Network

public protocol ConnectionDelegate: AnyObject {
    func notify(_ connection: Connection, is status: ConnectionStatus)
}

public enum ConnectionStatus: Equatable {
    case initialized
    case asking
    case accepted
    case uploading(progressInPercent: UInt)
    case done
    case abort(_ reason: AbortReason)

    public enum AbortReason {
        case denied
        case timeout
        case canceled
    }
}

public class Connection {

    public enum ConnectionError: Error {
        case alreadySendingError
        case noFilesProvided
    }

    public weak var delegate: ConnectionDelegate?
    public internal(set) var status: ConnectionStatus {
        didSet {
            self.delegate?.notify(self, is: status)
        }
    }

    public let peer: Peer
    public var files: [URL]?

    var ongoingRequest: HTTPClient?

    init(peer: Peer) {
        self.peer = peer
        self.status = .initialized
    }

    func send(file: URL, using client: Client) throws {
        try send(files: [file], using: client)
    }

    func send(files: [URL], using client: Client) throws {
        if self.status != ConnectionStatus.initialized {
            throw ConnectionError.alreadySendingError
        }
        self.files = files
        try ask(using: client)
    }

    public func cancel() {
        // ongoingRequest.cancel()
        status = ConnectionStatus.abort(.canceled)
    }

    func dataToByteBuffer(_ data: Data) -> ByteBuffer {
        var buffer = ByteBufferAllocator.init().buffer(capacity: data.count)
        buffer.writeBytes([UInt8](data))
        return buffer
    }

    func randomSenderID() -> Data {
        return Data(Data(count: 6).map({ _ in return UInt8.random(in: 0...UInt8.max) }))
    }

    func ask(using client: Client) throws {
        assert(self.status != .asking)
        // let fileHandle = NIOFileHandle(path: file, mode: .read, flags: .default)

        var askRequestBody = AskRequestBody()
        askRequestBody.SenderComputerName = "PrivateDrop"
        askRequestBody.SenderModelName = "PrivateDrop"
        askRequestBody.BundleID = "com.apple.finder"
        askRequestBody.SenderID = randomSenderID().base16EncodedString()
        askRequestBody.ConvertMediaFormats = false

        guard let files = self.files else {
            throw ConnectionError.noFilesProvided
        }
        askRequestBody.Files = []
        for file in files {
            let fileWrapper = try FileWrapper(url: file)
            var fileInfo = AskRequestBody.FileInfo()
            let fileName = file.lastPathComponent

            fileInfo.FileName = fileName
            fileInfo.FileBomPath = "./\(fileName)"
            fileInfo.FileType = "public.content"  // TODO use UTI file type
            fileInfo.FileIsDirectory = fileWrapper.isDirectory
            fileInfo.ConvertMediaFormats = false

            askRequestBody.Files.append(fileInfo)
        }

        let askRequestBodyEncoded = try PropertyListEncoder().encode(askRequestBody)

        client.request(with: self.peer, uri: "/Ask", body: askRequestBodyEncoded) { (head, _) in
            // response body is unused
            // let data = body.getData(at: body.readerIndex, length: body.readableBytes) ?? Data()
            // let response = (try? PropertyListDecoder().decode(DiscoverResponseBody.self, from: data)) ?? DiscoverResponseBody()

            // clear this request
            self.ongoingRequest = nil

            do {
                if head.status.code == 200 {
                    self.status = .accepted
                    try self.upload(using: client)
                } else {
                    self.status = .abort(.denied)
                }
            } catch {
                Log.error(system: .client, message: "Upload failed\n%@", String(describing: error))
            }
        }

        status = .asking
    }

    func upload(using client: Client) throws {
        let headers = [
            ("Transfer-Encoding", "Chunked"),
            ("Content-Type", "application/x-cpio"),
        ]

        // TODO: Upload for multiple files
        guard let fileURL = self.files?.first else {
            throw ConnectionError.noFilesProvided
        }
        PrivateDrop.testDelegate?.startsSendingFile()

        let uploadRequestBody = try Libarchive.archiveToCPIO(directory: fileURL)

        print(uploadRequestBody)
        client.request(with: self.peer, uri: "/Upload", head: headers, body: uploadRequestBody) {
            (head, _) in
            // clear this request

            PrivateDrop.testDelegate?.fileSent(payloadSize: uploadRequestBody.count)

            if head.status.code == 200 {
                self.status = .done
            } else {
                self.status = .abort(.canceled)
            }
        }
        status = .uploading(progressInPercent: 0)

    }

}
