//
//  AppPreferences.swift
//  EasyDial
//
//  Plain Swift struct for single-row app settings.
//  No Core Data / SwiftData imports — views stay persistence-agnostic.
//

import Foundation

struct AppPreferences {
    var id: UUID
    var hasCompletedSetup: Bool
    var themeRaw: String
    var voicePromptsEnabled: Bool
    var sosEnabled: Bool
    /// Emergency destination when SOS fires (digits/+ only).
    var emergencyPhoneNumber: String
    /// BCP-47 language code for TTS and UI (`en`, `ar`, `es`, `hi` only).
    var preferredLanguageCode: String
    /// Optional Dynamic Type override; nil means follow system.
    var dynamicTypeSizeRaw: String?

    init(
        id: UUID = UUID(),
        hasCompletedSetup: Bool = false,
        themeRaw: String = AppTheme.light.rawValue,
        voicePromptsEnabled: Bool = true,
        sosEnabled: Bool = true,
        emergencyPhoneNumber: String = "",
        preferredLanguageCode: String = "en",
        dynamicTypeSizeRaw: String? = nil
    ) {
        self.id = id
        self.hasCompletedSetup = hasCompletedSetup
        self.themeRaw = themeRaw
        self.voicePromptsEnabled = voicePromptsEnabled
        self.sosEnabled = sosEnabled
        self.emergencyPhoneNumber = emergencyPhoneNumber
        self.preferredLanguageCode = preferredLanguageCode
        self.dynamicTypeSizeRaw = dynamicTypeSizeRaw
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .light }
        set { themeRaw = newValue.rawValue }
    }

    var emergencySettings: EmergencySettings {
        get { EmergencySettings(isEnabled: sosEnabled, emergencyPhoneNumber: emergencyPhoneNumber) }
        set {
            sosEnabled = newValue.isEnabled
            emergencyPhoneNumber = newValue.emergencyPhoneNumber
        }
    }

    /// Trimmed emergency number suitable for dialing; empty string when invalid.
    var sanitizedEmergencyPhoneNumber: String {
        CallService.sanitizePhone(emergencyPhoneNumber)
    }
}
