//
//  SettingsViewModel.swift
//  EasyDial
//
//  Helpers for Dynamic Type labels and available sizes.
//

import Foundation
import SwiftUI

@MainActor
enum SettingsViewModel {
    static let dynamicTypeChoices: [DynamicTypeSize] = DynamicTypeStorage.choices

    static func resolvedDynamicType(storedRaw: String?) -> DynamicTypeSize? {
        DynamicTypeStorage.resolvedSize(storedRaw: storedRaw)
    }

    static func localizedDynamicTypeLabel(_ size: DynamicTypeSize, locale: Locale) -> String {
        let key: String
        switch size {
        case .xSmall:       key = "settings.dynamic_type.xSmall"
        case .small:        key = "settings.dynamic_type.small"
        case .medium:       key = "settings.dynamic_type.medium"
        case .large:        key = "settings.dynamic_type.large"
        case .xLarge:       key = "settings.dynamic_type.xLarge"
        case .xxLarge:      key = "settings.dynamic_type.xxLarge"
        case .xxxLarge:     key = "settings.dynamic_type.xxxLarge"
        case .accessibility1: key = "settings.dynamic_type.ax1"
        case .accessibility2: key = "settings.dynamic_type.ax2"
        case .accessibility3: key = "settings.dynamic_type.ax3"
        case .accessibility4: key = "settings.dynamic_type.ax4"
        case .accessibility5: key = "settings.dynamic_type.ax5"
        @unknown default:   key = "settings.dynamic_type.medium"
        }
        return L10n.string(key, locale: locale)
    }
}
