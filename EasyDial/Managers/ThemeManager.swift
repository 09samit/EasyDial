//
//  ThemeManager.swift
//  EasyDial
//
//  Observes persisted theme + reduce transparency / contrast preferences for SwiftUI injection.
//

import Combine
import SwiftData
import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var currentTheme: AppTheme = .light
    @Published private(set) var colors: ThemeColors = ThemeColors.palette(for: .light)

    private var modelContext: ModelContext?

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshFromStore()
    }

    func refreshFromStore() {
        guard let ctx = modelContext else { return }
        let fd = FetchDescriptor<AppPreferences>()
        if let prefs = try? ctx.fetch(fd).first {
            apply(theme: prefs.theme)
        } else {
            apply(theme: .light)
        }
    }

    func apply(theme: AppTheme) {
        currentTheme = theme
        colors = ThemeColors.palette(for: theme)
    }

    func persist(theme: AppTheme) {
        guard let ctx = modelContext else { return }
        let fd = FetchDescriptor<AppPreferences>()
        if let prefs = try? ctx.fetch(fd).first {
            prefs.theme = theme
        }
        apply(theme: theme)
        try? ctx.save()
    }
}
