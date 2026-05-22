//
//  ThemeManager.swift
//  EasyDial
//
//  Observes app preferences to apply theme. No longer depends on ModelContext.
//

import Combine
import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var currentTheme: AppTheme = .light
    @Published private(set) var colors: ThemeColors = ThemeColors.palette(for: .light)

    private var cancellables = Set<AnyCancellable>()

    /// Subscribes to AppStore.$preferences and auto-applies theme on every change.
    func attach(store: AppStore) {
        store.$preferences
            .compactMap { $0?.theme }
            .removeDuplicates()
            .sink { [weak self] theme in
                self?.apply(theme: theme)
            }
            .store(in: &cancellables)
        // Apply immediately from whatever is currently loaded.
        apply(theme: store.preferences?.theme ?? .light)
    }

    func apply(theme: AppTheme) {
        currentTheme = theme
        colors = ThemeColors.palette(for: theme)
    }
}
