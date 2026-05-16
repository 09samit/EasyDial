//
//  AppServices.swift
//  EasyDial
//
//  Lightweight service container for predictable injection across views (no scattered singletons).
//

import SwiftUI

/// Shared app-level services. Wired once at launch for consistent behavior under VoiceOver and Dynamic Type.
final class AppServices {
    let speech = SpeechService()
    let haptics = HapticService()
    let calls = CallService()
    let accessibility = AccessibilityService()
    let contacts = ContactService()
    let permissions = PermissionManager()

    init() {
        haptics.prepare()
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices()
}

extension EnvironmentValues {
    var appServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}
