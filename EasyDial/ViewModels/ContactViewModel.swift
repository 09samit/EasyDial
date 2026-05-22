//
//  ContactViewModel.swift
//  EasyDial
//
//  Form state for adding or editing a favorite contact.
//

import Combine
import Foundation

@MainActor
final class ContactViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var phoneNumber: String = ""
    @Published var photoData: Data?

    /// Whether the user explicitly changed the photo during this edit session.
    var photoChanged = false
    /// Whether the user explicitly removed the photo during this edit session.
    var photoRemoved = false

    /// Resets form state from a saved contact, loading photo from the provided storage.
    func reset(from contact: FavoriteContact, photoStorage: any ContactPhotoStorage) {
        displayName = contact.displayName
        phoneNumber = contact.phoneNumber
        photoData = photoStorage.load(for: contact.id)
        photoChanged = false
        photoRemoved = false
    }

    func validate(locale: Locale) -> String? {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = CallService.sanitizePhone(phoneNumber)
        if name.isEmpty { return L10n.string("validation.name_required", locale: locale) }
        if phone.isEmpty { return L10n.string("validation.phone_required", locale: locale) }
        return nil
    }
}
