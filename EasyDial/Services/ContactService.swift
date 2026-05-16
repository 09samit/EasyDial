//
//  ContactService.swift
//  EasyDial
//
//  Contacts.framework bridge for importing people during setup.
//

import Contacts
import Foundation
import UIKit

struct ImportedContact: Identifiable, Hashable {
    let id: String
    let givenName: String
    let familyName: String
    let organizationName: String
    let phoneNumbers: [String]
    let thumbnailImageData: Data?
    /// Localized fallback when the system contact has no usable name.
    let anonymousDisplayLabel: String

    var displayName: String {
        let full = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        if !organizationName.isEmpty { return organizationName }
        return anonymousDisplayLabel
    }
}

final class ContactService {
    private let store = CNContactStore()

    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor
    ]

    func fetchContacts(locale: Locale) throws -> [ImportedContact] {
        let anonymous = L10n.string("contact.no_name", locale: locale)
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName
        var results: [ImportedContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let phones = contact.phoneNumbers
                .map { $0.value.stringValue }
                .filter { !CallService.sanitizePhone($0).isEmpty }
            guard !phones.isEmpty else { return }

            let thumbData = contact.thumbnailImageData ?? contact.imageData
            let thumb = ImageDataOptimizer.thumbnailJPEG(from: thumbData)
            results.append(
                ImportedContact(
                    id: contact.identifier,
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    organizationName: contact.organizationName,
                    phoneNumbers: phones,
                    thumbnailImageData: thumb,
                    anonymousDisplayLabel: anonymous
                )
            )
        }
        return results.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func loadContact(identifier: String, locale: Locale) throws -> ImportedContact? {
        let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        return importedContact(from: contact, locale: locale)
    }

    /// Resolves a picker selection by re-fetching the unified contact (picker rows are often partial).
    func resolveImport(
        pickerContact: CNContact,
        preselectedPhone: String? = nil,
        locale: Locale
    ) -> ImportedContact? {
        if let unified = try? store.unifiedContact(
            withIdentifier: pickerContact.identifier,
            keysToFetch: keysToFetch
        ) {
            return importedContact(from: unified, preselectedPhone: preselectedPhone, locale: locale)
        }
        return importedContact(from: pickerContact, preselectedPhone: preselectedPhone, locale: locale)
    }

    /// Builds an import model from a contact, optionally pinning the chosen phone number.
    func importedContact(
        from contact: CNContact,
        preselectedPhone: String? = nil,
        locale: Locale
    ) -> ImportedContact? {
        let phones = contact.phoneNumbers
            .map { $0.value.stringValue }
            .filter { !CallService.sanitizePhone($0).isEmpty }
        guard !phones.isEmpty else { return nil }

        var orderedPhones = phones
        if let preselectedPhone,
           !CallService.sanitizePhone(preselectedPhone).isEmpty {
            if let index = orderedPhones.firstIndex(of: preselectedPhone), index > 0 {
                orderedPhones.remove(at: index)
                orderedPhones.insert(preselectedPhone, at: 0)
            } else if !orderedPhones.contains(where: { CallService.sanitizePhone($0) == CallService.sanitizePhone(preselectedPhone) }) {
                orderedPhones.insert(preselectedPhone, at: 0)
            }
        }

        let thumbData = contact.thumbnailImageData ?? contact.imageData
        return ImportedContact(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            organizationName: contact.organizationName,
            phoneNumbers: orderedPhones,
            thumbnailImageData: ImageDataOptimizer.thumbnailJPEG(from: thumbData),
            anonymousDisplayLabel: L10n.string("contact.no_name", locale: locale)
        )
    }

    private func importedContact(from contact: CNContact, locale: Locale) -> ImportedContact? {
        importedContact(from: contact, preselectedPhone: nil, locale: locale)
    }
}
