//
//  RootView.swift
//  EasyDial
//
//  Chooses setup vs home, applies locale / Dynamic Type overrides from saved preferences.
//

import SwiftData
import SwiftUI

private func layoutDirection(for languageCode: String) -> LayoutDirection {
    Locale.Language(identifier: languageCode).characterDirection == .rightToLeft
        ? .rightToLeft
        : .leftToRight
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var services
    @EnvironmentObject private var themeManager: ThemeManager
    @Query(sort: \AppPreferences.id) private var preferencesQuery: [AppPreferences]

    private var preferences: AppPreferences? { preferencesQuery.first }

    /// Locale for strings before `AppPreferences` exists (first launch).
    private var loadingLocale: Locale {
        if let code = preferencesQuery.first?.preferredLanguageCode {
            return Locale(identifier: code)
        }
        return Locale(identifier: "en")
    }

    var body: some View {
        Group {
            if let prefs = preferences {
                if prefs.hasCompletedSetup {
                    HomeView()
                        .environment(\.locale, Locale(identifier: prefs.preferredLanguageCode))
                        .environment(\.layoutDirection, layoutDirection(for: prefs.preferredLanguageCode))
                        .id(prefs.preferredLanguageCode)
                } else {
                    SetupFlowView()
                        .environment(\.locale, Locale(identifier: prefs.preferredLanguageCode))
                        .environment(\.layoutDirection, layoutDirection(for: prefs.preferredLanguageCode))
                        .id(prefs.preferredLanguageCode)
                }
            } else {
                ZStack {
                    Color(red: 252 / 255, green: 248 / 255, blue: 241 / 255)
                    ProgressView(L10n.string("common.loading", locale: loadingLocale))
                        .accessibilityLabel(Text(L10n.string("common.loading", locale: loadingLocale)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(services.accessibility.preferredAnimation(), value: preferences?.hasCompletedSetup)
        .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
        .tint(themeManager.colors.primaryButton)
        .onAppear {
            ensurePreferences()
            normalizeLanguageCodeIfNeeded()
            themeManager.attach(modelContext: modelContext)
            themeManager.refreshFromStore()
        }
        .modifier(DynamicTypePreferenceModifier(preferences: preferences))
    }

    private func ensurePreferences() {
        guard preferencesQuery.isEmpty else { return }
        modelContext.insert(AppPreferences())
        try? modelContext.saveOrThrow()
    }

    /// Migrates languages removed from the app (e.g. gu/mr/ta) to English.
    private func normalizeLanguageCodeIfNeeded() {
        guard let prefs = preferencesQuery.first else { return }
        let supported = Set(AppLanguage.allCases.map(\.rawValue))
        guard !supported.contains(prefs.preferredLanguageCode) else { return }
        prefs.preferredLanguageCode = AppLanguage.english.rawValue
        try? modelContext.saveOrThrow()
    }
}

/// Applies your saved Dynamic Type when provided; otherwise follows the system setting.
private struct DynamicTypePreferenceModifier: ViewModifier {
    let preferences: AppPreferences?

    func body(content: Content) -> some View {
        if let raw = preferences?.dynamicTypeSizeRaw,
           let size = SettingsViewModel.resolvedDynamicType(storedRaw: raw) {
            content.dynamicTypeSize(size)
        } else {
            content
        }
    }
}

#Preview {
    RootView()
        .environment(\.appServices, AppServices())
        .environmentObject(ThemeManager())
        .modelContainer(PreviewSampleData.container)
}
