//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Foundation

/// Handle mDNS, DNS-SD publication for AirDrop
class Advertiser: NSObject, NetServiceDelegate {
    var service: NetService?
    private var runLoop = RunLoop()

    /// Advertise the AirDrop service over AWDL and WiFi
    func advertiseAirDrop(configuration: PrivateDrop.Configuration, serverPort: Int32) {
        self.service = NetService(
            domain: "local.", type: "_airdrop._tcp.", name: configuration.general.serviceID,
            port: serverPort)

        let txtData = self.generateTXTRecordData(with: configuration)

        if self.service?.setTXTRecord(txtData) == false {
            self.service?.setTXTRecord(nil)
        }

        self.service?.includesPeerToPeer = true
        self.service?.delegate = self

        self.service?.publish()
        //        self.service?.schedule(in: self.runLoop, forMode: .common)
    }

    /// Generate the TXT record data.
    /// - Parameter configuration: The PrivateDrop Config
    /// - Returns: Data containing the TXT record data
    func generateTXTRecordData(with configuration: PrivateDrop.Configuration) -> Data {
        // Flags
        var txtString = "\t"
        txtString += "flags=\(configuration.general.flags)"  // "\tflags=136"

        return txtString.data(using: .ascii)!
    }

    /// Stop advertising AirDrop
    func stopAdvertisingAirDrop() {
        self.service?.stop()
        self.service?.remove(from: self.runLoop, forMode: .common)
        self.service = nil
    }

    // MARK: - NetServiceDelegate

    func netServiceDidPublish(_ sender: NetService) {
        print("Published service \(String(describing: sender))")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("Publish failed: \(errorDict)")
    }

}
