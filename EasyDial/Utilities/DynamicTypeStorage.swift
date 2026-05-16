//
//  DynamicTypeStorage.swift
//  EasyDial
//
//  Stable string keys for persisted Dynamic Type overrides (not `String(describing:)`).
//

import SwiftUI

enum DynamicTypeStorage {
    static let choices: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
    ]

    static func storageKey(for size: DynamicTypeSize) -> String {
        switch size {
        case .xSmall: return "xSmall"
        case .small: return "small"
        case .medium: return "medium"
        case .large: return "large"
        case .xLarge: return "xLarge"
        case .xxLarge: return "xxLarge"
        case .xxxLarge: return "xxxLarge"
        case .accessibility1: return "accessibility1"
        case .accessibility2: return "accessibility2"
        case .accessibility3: return "accessibility3"
        case .accessibility4: return "accessibility4"
        case .accessibility5: return "accessibility5"
        @unknown default:
            return "large"
        }
    }

    static func resolvedSize(storedRaw: String?) -> DynamicTypeSize? {
        guard let storedRaw, !storedRaw.isEmpty else { return nil }
        if let match = choices.first(where: { storageKey(for: $0) == storedRaw }) {
            return match
        }
        // Migrate records saved with `String(describing:)` before this helper existed.
        return choices.first { String(describing: $0) == storedRaw }
    }
}
