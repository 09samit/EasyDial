//
//  RootView.swift
//  EasyDial
//
//  Chooses setup vs home, applies locale / Dynamic Type overrides from saved preferences.
//

import SwiftUI

private func layoutDirection(for languageCode: String) -> LayoutDirection {
    Locale.Language(identifier: languageCode).characterDirection == .rightToLeft
        ? .rightToLeft
        : .leftToRight
}

struct RootView: View {
    @Environment(\.appServices) private var services
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: AppStore

    private var preferences: AppPreferences? { store.preferences }

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
                    ProgressView(L10n.string("common.loading", locale: Locale(identifier: "en")))
                        .accessibilityLabel(
                            Text(L10n.string("common.loading", locale: Locale(identifier: "en")))
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(services.accessibility.preferredAnimation(), value: preferences?.hasCompletedSetup)
        .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
        .tint(themeManager.colors.primaryButton)
        .modifier(DynamicTypePreferenceModifier(preferences: preferences))
    }
}

/// Applies the saved Dynamic Type when available; otherwise follows the system setting.
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
        .environmentObject(AppStore.preview)
}
