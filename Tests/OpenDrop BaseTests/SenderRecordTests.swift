//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 17.06.20.
//
import Foundation
import XCTest

@testable import PrivateDrop_Base

class SenderRecordTests: XCTestCase {

    var senderRecordCMS: Data {
        let resourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent("TestResources/CMS")
        let cmsURL = resourceDir.appendingPathComponent("senderrecord.data")
        let senderRecordCMSData = try! Data(contentsOf: cmsURL)
        //        print(senderRecordCMSData.base64EncodedString())
        return senderRecordCMSData
    }

    var expectedSenderRecord: RecordData {
        let resourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent("TestResources/CMS")
        let plistURL = resourceDir.appendingPathComponent("senderrecord.plist")
        let plistData = try! Data(contentsOf: plistURL)

        let senderR = try! PropertyListDecoder().decode(RecordData.self, from: plistData)

        return senderR
    }

    func testCMSDecoding() throws {
        do {
            // Do not validate
            let senderRecord = try RecordData.from(cms: self.senderRecordCMS)
            XCTAssertEqual(senderRecord, self.expectedSenderRecord)
        } catch {
            Log.error(system: .server, message: "%@", String(describing: error))
            Log.error(
                system: .server, message: "%@",
                NSError(domain: NSOSStatusErrorDomain, code: (error as NSError).code, userInfo: [:])
            )
            XCTFail()
        }

    }
}
