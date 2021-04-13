//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 15.05.20.
//

import Foundation

@testable import PrivateDrop_Base

extension Bundle {
    static var test: Bundle {
        return Bundle(for: PSITest.self)
    }

    var clientCertificate: Data {
        try! Data(
            contentsOf: Bundle.test.url(forResource: "ClientCertificate", withExtension: "p12")!)
    }

    var clientSignedY: Data {
        try! Data(contentsOf: Bundle.test.url(forResource: "5_y", withExtension: "cms")!)
    }

    var clientOtherVals: Data {
        try! Data(contentsOf: Bundle.test.url(forResource: "5_other", withExtension: "plist")!)
    }

    var serverCertificate: Data {
        try! Data(
            contentsOf: Bundle.test.url(forResource: "ServerCertificate", withExtension: "p12")!)
    }

    var serverSignedY: Data {
        try! Data(contentsOf: Bundle.test.url(forResource: "10_y", withExtension: "cms")!)
    }

    var serverOtherVals: Data {
        try! Data(contentsOf: Bundle.test.url(forResource: "10_other", withExtension: "plist")!)
    }

    var recordData: Data {
        try! Data(contentsOf: Bundle.test.url(forResource: "senderrecord", withExtension: "data")!)
    }
}

extension PrivateDrop.Configuration {
    static var testEmpty: PrivateDrop.Configuration {

        let certificate = Bundle.test.serverCertificate

        let signedY = Bundle.test.serverSignedY
        let otherVals = Bundle.test.serverOtherVals

        let contacts = ["seemoo-iphone8@mr-alex.dev"]

        return try! PrivateDrop.Configuration(
            recordData: Bundle.test.recordData, pkcs12: certificate, computerName: "Test-Device",
            modelName: "MacBook 10,3", contactsOnly: true, contacts: contacts, signedY: signedY,
            otherPrecomputedValues: otherVals)
    }

    static func testServer(
        with contacts: [String] = ["seemoo-iphone8@mr-alex.dev"], and y: Data, otherVals: Data
    ) throws -> PrivateDrop.Configuration {
        let certificate = Bundle.test.serverCertificate

        let recordData = Bundle.test.recordData

        return try PrivateDrop.Configuration(
            recordData: recordData,
            pkcs12: certificate,
            computerName: "Test-Server",
            modelName: "MacBook 10,3",
            contactsOnly: true,
            contacts: contacts,
            signedY: y,
            otherPrecomputedValues: otherVals)
    }

    static var testClient: PrivateDrop.Configuration {

        let certificate = Bundle.test.clientCertificate

        let signedY = Bundle.test.clientSignedY
        let otherVals = Bundle.test.clientOtherVals
        let contacts = ["seemoo-iphone8@mr-alex.dev"]

        return try! PrivateDrop.Configuration(
            recordData: Bundle.test.recordData, pkcs12: certificate, computerName: "Test-Device",
            modelName: "MacBook 10,3", contactsOnly: true, contacts: contacts, signedY: signedY,
            otherPrecomputedValues: otherVals)
    }

    static func testClient(
        with contacts: [String] = ["seemoo-iphone8@mr-alex.dev"], and y: Data, otherVals: Data
    ) throws -> PrivateDrop.Configuration {
        let certificate = Bundle.test.clientCertificate

        let recordData = Bundle.test.recordData

        return try! PrivateDrop.Configuration(
            recordData: recordData,
            pkcs12: certificate,
            computerName: "Test-Client",
            modelName: "MacBook 10,3",
            contactsOnly: true,
            contacts: contacts,
            signedY: y,
            otherPrecomputedValues: otherVals)
    }

}

extension RecordData {
    static var senderRecordCMS: Data {
        let resourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent("TestResources/CMS")
        let cmsURL = resourceDir.appendingPathComponent("senderrecord.data")
        let senderRecordCMSData = try! Data(contentsOf: cmsURL)
        //        print(senderRecordCMSData.base64EncodedString())
        return senderRecordCMSData
    }

    static var testSenderRecord: RecordData {
        let resourceDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
            .appendingPathComponent("TestResources/CMS")
        let plistURL = resourceDir.appendingPathComponent("senderrecord.plist")
        let plistData = try! Data(contentsOf: plistURL)

        let senderR = try! PropertyListDecoder().decode(RecordData.self, from: plistData)

        return senderR
    }
}
