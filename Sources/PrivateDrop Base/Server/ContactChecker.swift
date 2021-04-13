//
//  File.swift
//
//
//  Created by Alex - SEEMOO on 22.06.20.
//

#if os(iOS) || os(watchOS) || os(macOS)
    import Foundation
    import Contacts

    class LocalContacts {
        /// Hash - Contact identifier
        private var contacts: [String: String]

        private var contactHashes: Set<String> {
            return Set(contacts.keys)
        }

        init() {
            self.contacts = [:]
            self.fetchContacts()
        }

        func fetchContacts() {
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { (granted, _) in
                guard granted else { return }

                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactIdentifierKey as CNKeyDescriptor,
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                    CNContactEmailAddressesKey as CNKeyDescriptor,
                ]

                let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)

                try? store.enumerateContacts(with: fetchRequest) { (contact, _) in
                    // Hash all phone numbers and mail addresses
                    // Store them in the dictionaty with the contact identifier
                    let identifier = contact.identifier
                    for phoneNumber in contact.phoneNumbers {
                        let normalized = self.normalize(phoneNumber: phoneNumber.value.stringValue)
                        guard
                            let hashed = try? Hash.sha256(string: normalized).base16EncodedString()
                        else {
                            continue
                        }
                        self.contacts[hashed] = identifier
                    }

                    for email in contact.emailAddresses {
                        guard
                            let hashed = try? Hash.sha256(string: email.value as String)
                                .base16EncodedString()
                        else { continue }
                        self.contacts[hashed] = identifier
                    }
                }
            }
        }

        func findContact(for hashes: [String]) -> CNContact? {

            for hash in hashes {
                guard let contactId = self.contacts[hash] else { continue }
                let store = CNContactStore()
                let contact = try? store.unifiedContact(
                    withIdentifier: contactId,
                    keysToFetch: [
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactFamilyNameKey as CNKeyDescriptor,
                    ])

                return contact
            }

            return nil
        }

        func normalize(phoneNumber: String) -> String {
            var normalized = phoneNumber
            if phoneNumber.hasPrefix("00") {
                normalized.removeFirst(2)
            }

            if phoneNumber.hasPrefix("+") {
                normalized.removeFirst(2)
            }

            return normalized
        }

    }
#endif
