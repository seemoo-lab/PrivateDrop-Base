//
//  PrivateDropConfiguration.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 27.07.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

import Foundation
import PSI

// swiftlint:disable nesting
extension PrivateDrop {

    /// The struct containing the entire configuration for opendrop. The configuration is seperated in multiple parts
    public struct Configuration: Codable {

        /// General configuration contains the name of the computer & model that is used
        public struct General: Codable {
            /// The computer name, e.g. `John's MacBook`
            public let computerName: String
            /// The model used, e.g. `Aiden's iPhone`
            public let modelName: String
            /// AirDrop and PrivateDrop flags to identify if it supports PSI
            public var flags: UInt8 =
                AirDropFlags.supportsMixedTypes.rawValue | AirDropFlags.supportsDiscover.rawValue
                | AirDropFlags.supportsPSI.rawValue

            /// The id used to advertise the opendrop service over the network.
            var serviceID: String = {
                var uuid = UUID().uuid
                let uuidData = Data(bytes: &uuid, count: MemoryLayout.size(ofValue: uuid)).subdata(
                    in: 0..<6)
                return uuidData.hexEncodedString()
            }()

            /// Supports PrivateDrop by default
            var supportsPrivateDrop = true
        }

        /// The contacts struct contains data necessary for identifying if a connected peer is in the address book.
        public struct Contacts: Codable {

            /// The own record data contains hashes from Apple. Can be nil, but it will result in an issue where it is not possible to identify the other contacts
            public let recordData: Data?
            /// If true, the receiver, will only receive AirDrop Data from contacts
            public let contactsOnly: Bool
            /// An array of e-mail addresses and phone numbers
            public let contacts: [String]
            //            /// Own contact ids. Used for identifiaction in PSI (later will be like record data)
            //            let ownContactIds: [String]

            /// Pre-computed y-Values. Have to be signed in initialized
            public let yValues: [Data]?

            /// PKCS7 encoded and signed y-values. The signed data is a property list with one entry y and an array of data
            public let signedY: Data?

            /// Other precomputed values. Not signed, but encoded as a property list
            public let otherPrecomputedValues: PrivatePSIValues?

            /// Initialize the contacts for usage with the PSI protocol
            ///
            /// The first values are static and precomputed.
            /// They have to be part of the initializer, because otherwise the security and privacy cannot be proved nor guaranteed.
            /// The app will not perform AirDrop PSI without adding them here.
            /// - Parameters:
            ///   - recordData: AirDrop 1 Record data
            ///   - contactsOnly: Flag that decides if AirDrop runs in contacts only
            ///   - contacts: A list of contacts
            ///   - signedY: PKCS7 Signed y-values which are pre-computed
            ///   - otherPrecomputedValues: pre-computed a,h and ids which match the y-values
            /// - Throws: Errors if the verification of the pre-computed values fails
            init(
                recordData: Data?, contactsOnly: Bool, contacts: [String],
                signedY: Data?, otherPrecomputedValues: Data?
            ) throws {

                self.recordData = recordData
                self.contactsOnly = contactsOnly
                self.contacts = contacts

                if let signedY = signedY,
                    let otherPrecomputedValues = otherPrecomputedValues
                {
                    PSI.initialize(config: .init(useECPointCompression: true))

                    // Check the validity of the signed data
                    let yValues = try PSISignedValues.verify(signedData: signedY)

                    let otherVals = try PropertyListDecoder().decode(
                        PrivatePSIValues.self, from: otherPrecomputedValues)

                    // Check if both sets match
                    let testVerifier = try Verifier(
                        ids: otherVals.ids, y: yValues.y, a: otherVals.a, hashes: otherVals.hashes)
                    guard testVerifier.validateY(with: yValues.y) else {
                        throw PSISignedValues.Error.verificationFailed
                    }

                    self.otherPrecomputedValues = otherVals
                    self.signedY = signedY
                    self.yValues = yValues.y
                } else {
                    self.otherPrecomputedValues = nil
                    self.signedY = nil
                    self.yValues = nil
                }

            }
        }

        /// Certificates needed for execution. E.g. the TLS certificates used
        public struct Certificates: Codable {
            /// Key and certificate in a PKCS12 file
            public let pkcs12Data: Data
        }

        /// Testing configuration.
        public struct Testing: Codable {
            /// If true the sender record id will be matched with the certificate subject name. If this fails he transmission will be stopped
            public var validateSenderRecordWithCertificate: Bool = true
            /// If true, PrivateDrop will match the contacts from the sender Record with its own contact list
            public var matchContacts: Bool = true
        }

        public let general: General
        public let contacts: Contacts
        public let certificates: Certificates
        public var testing = Testing()

        /// Configuration for using PrivateDrop. PrivateDrop needs sender record data and a certificate to be fully compatible with AirDrop/
        /// - Parameters:
        ///   - senderRecordData: The sender record data is an Apple signed binary blob that contains contact hashes
        ///   - pksc12: The certificate is an Apple generated certificate for the user's iCloud account. Stored in a PKCS12 that contains the key as well
        ///   - computerName: The computer name / device name. Will be fetched automatically if nil
        ///   - modelName: The model name (e.g. MacBook 11,2). Will be fetched automatically if nil
        public init(
            recordData: Data?,
            pkcs12: Data, computerName: String? = nil,
            modelName: String? = nil,
            contactsOnly: Bool = false,
            contacts: [String] = [],
            signedY: Data,
            otherPrecomputedValues: Data,
            supportsPrivateDrop: Bool = false
        ) throws {

            self.general = General(
                computerName: computerName ?? Configuration.currentComputerName() ?? "Unknown",
                modelName: modelName ?? Configuration.currentModel() ?? "Unknown model",
                supportsPrivateDrop: supportsPrivateDrop
            )

            self.certificates = Certificates(pkcs12Data: pkcs12)

            self.contacts = try Contacts(
                recordData: recordData,
                contactsOnly: contactsOnly,
                contacts: contacts,
                signedY: signedY,
                otherPrecomputedValues: otherPrecomputedValues)
        }
    }
}
