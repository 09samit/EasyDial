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

    func reset(from contact: FavoriteContact?) {
        guard let contact else {
            displayName = ""
            phoneNumber = ""
            photoData = nil
            return
        }
        displayName = contact.displayName
        phoneNumber = contact.phoneNumber
        photoData = contact.photoData
    }

    func validate(locale: Locale) -> String? {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = CallService.sanitizePhone(phoneNumber)
        if name.isEmpty { return L10n.string("validation.name_required", locale: locale) }
        if phone.isEmpty { return L10n.string("validation.phone_required", locale: locale) }
        return nil
    }
}
