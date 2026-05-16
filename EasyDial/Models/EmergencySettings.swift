//
//  EmergencySettings.swift
//  EasyDial
//
//  SOS configuration values (persisted via `AppPreferences`). Kept separate for clarity and future SMS/location hooks.
//

import Foundation

/// Snapshot of emergency calling behavior for UI and services.
struct EmergencySettings: Equatable {
    var isEnabled: Bool
    /// E.164-friendly digits for `tel:`.
    var emergencyPhoneNumber: String

    static let `default` = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "")

    /// Placeholders for future emergency alerts (SMS, push, location). Wire into services when backend exists.
    var futureSMSAlertsEnabled: Bool { false }
    var futureLocationSharingEnabled: Bool { false }
    var futureEmergencyAlertsEnabled: Bool { false }
}
