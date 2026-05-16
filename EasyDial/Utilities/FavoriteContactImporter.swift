//
//  FavoriteContactImporter.swift
//  EasyDial
//
//  Imports a system contact into SwiftData favorites.
//

import Contacts
import Foundation
import SwiftData

enum FavoriteContactImporter {
    @MainActor
    static func addFavorite(
        from selection: ContactPickerSelection,
        favorites: [FavoriteContact],
        limit: Int,
        contacts: ContactService,
        locale: Locale,
        modelContext: ModelContext
    ) -> FavoriteImportIssue? {
        let validator = FavoriteImportValidator(favorites: favorites, limit: limit)
        guard validator.canAdd else { return .atFavoriteLimit }

        let pickerContact: CNContact
        let preselectedPhone: String?
        switch selection {
        case .contact(let contact):
            pickerContact = contact
            preselectedPhone = nil
        case .phone(let contact, let number):
            pickerContact = contact
            preselectedPhone = number
        }

        guard let imported = contacts.resolveImport(
            pickerContact: pickerContact,
            preselectedPhone: preselectedPhone,
            locale: locale
        ) else {
            return .noDialablePhone
        }

        let phone = imported.phoneNumbers.first ?? ""
        let sanitized = CallService.sanitizePhone(phone)
        if let issue = validator.issue(contactID: imported.id, sanitizedPhone: sanitized) {
            return issue
        }

        let nextOrder = (favorites.map(\.sortOrder).max() ?? -1) + 1
        let favorite = FavoriteContact(
            sortOrder: nextOrder,
            displayName: imported.displayName,
            relationshipLabel: FavoriteContact.hiddenRelationshipLabel,
            phoneNumber: sanitized,
            photoData: ImageDataOptimizer.thumbnailJPEG(from: imported.thumbnailImageData),
            cnContactIdentifier: imported.id
        )
        modelContext.insert(favorite)
        do {
            try modelContext.saveOrThrow()
            return nil
        } catch {
            modelContext.delete(favorite)
            return .saveFailed
        }
    }
}

extension FavoriteImportIssue {
    func localizedMessage(locale: Locale, favoriteLimit: Int) -> String {
        switch self {
        case .atFavoriteLimit:
            return String(
                format: L10n.string("add.error.max_favorites", locale: locale),
                locale: locale,
                arguments: [Int64(favoriteLimit)]
            )
        case .duplicateContact, .duplicatePhone:
            return L10n.string("add.error.duplicate", locale: locale)
        case .noDialablePhone:
            return L10n.string("add.error.no_phone", locale: locale)
        case .saveFailed:
            return L10n.string("error.save_failed", locale: locale)
        }
    }
}
