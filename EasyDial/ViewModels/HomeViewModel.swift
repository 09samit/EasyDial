//
//  HomeViewModel.swift
//  EasyDial
//
//  Coordinates haptics, voice confirmation, and dialing for the home grid.
//

import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var lastErrorMessage: String?

    func clearError() {
        lastErrorMessage = nil
    }

    func initiateCall(
        for contact: FavoriteContact,
        preferences: AppPreferences,
        services: AppServices,
        locale: Locale
    ) {
        lastErrorMessage = nil
        services.speech.stop()
        services.haptics.softTap()
        services.speech.speakCalling(
            contactName: contact.displayName,
            languageCode: preferences.preferredLanguageCode,
            voicePromptsEnabled: preferences.voicePromptsEnabled
        )
        if let msg = services.calls.placeCallMessageIfFailed(contact.phoneNumber, locale: locale) {
            lastErrorMessage = msg
        }
    }
}
