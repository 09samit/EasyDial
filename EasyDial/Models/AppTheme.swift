//
//  AppTheme.swift
//  EasyDial
//
//  Theme identifiers for calm, healthcare-oriented appearance modes.
//

import SwiftUI

/// Visual theme selection persisted with SwiftData / preferences.
enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case highContrast

    var id: String { rawValue }

    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .light: return "theme.light"
        case .dark: return "theme.dark"
        case .highContrast: return "theme.highContrast"
        }
    }

    /// Drives navigation bar and system chrome so titles stay legible on themed backgrounds.
    var preferredColorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark, .highContrast: .dark
        }
    }
}
