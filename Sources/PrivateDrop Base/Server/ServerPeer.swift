//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 22.06.20.
//

import Foundation
import NIO

/// A `ServerPeer` is a device that connected to the Server and communicates with it.
class ServerPeer {
    /// The certificate's common name
    var commonName: String?
    /// The client certificate that was used be the peer to identify itself
    let peerCertificate: Data
    /// True if the peer is a contact
    var contactStatus: Peer.Status = .unknown
    /// The sender record of that peer if it has sent one
    var senderRecord: RecordData?
    /// The peer's address
    var address: SocketAddress?

    init(commonName: String? = nil, peerCertificate: Data) {
        self.commonName = commonName
        self.peerCertificate = peerCertificate
    }
}
