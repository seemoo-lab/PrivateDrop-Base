//
//  ContactsChecker.swift
//  PrivateDrop Base
//
//  Created by Alex - SEEMOO on 04.08.20.
//  Copyright © 2020 SEEMOO - TU Darmstadt. All rights reserved.
//

import Foundation

/// Class that checks if the supplied hashes in the record data is
class ContactsChecker {

    /// Own conctact ids
    var ownContacts: [String] = []

    /// Dictionary mapping hash to contact id
    var contactHashes: [String: String]?

    init(ownContactIds: [String]) {
        self.ownContacts = ownContactIds
    }

    /// Compute the hashes for the contact ids
    /// - Parameter contactsConfig: The contacts config
    func computeHashes(for contactsConfig: PrivateDrop.Configuration.Contacts) {

        self.ownContacts = contactsConfig.contacts
        self.computeHashes()
    }

    func computeHashes() {
        self.contactHashes = [:]
        self.ownContacts.forEach { (contactId) in
            guard let hash = try? Hash.sha256(string: contactId).base16EncodedString() else {
                return
            }
            self.contactHashes?[hash] = contactId
        }
    }

    /// Checks if the SenderRecord of the Discover is a contact. If so,
    func checkIfContact(senderRecord: RecordData) -> [String] {
        if self.contactHashes == nil {
            self.computeHashes()
        }
        guard let hashes = self.contactHashes else { return [] }
        var matches = [String]()

        // Compare hashes
        // Phone numbers
        for phoneNumber in senderRecord.ValidatedPhoneHashes {
            if let match = hashes[phoneNumber] {
                matches.append(match)
            }
        }

        // Compare Mail addresses
        for mailAddress in senderRecord.ValidatedEmailHashes {
            if let match = hashes[mailAddress] {
                matches.append(match)
            }
        }

        return matches
    }
}
