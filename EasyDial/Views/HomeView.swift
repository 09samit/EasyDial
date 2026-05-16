//
//  HomeView.swift
//  EasyDial
//
//  Primary surface: favorites grid (2 columns on iPhone, 3 on iPad) + persistent SOS bar (no swipe gestures, stable ordering).
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var services
    @Environment(\.locale) private var locale
    @EnvironmentObject private var themeManager: ThemeManager
    @Query(sort: \FavoriteContact.sortOrder) private var favorites: [FavoriteContact]
    @Query(sort: \AppPreferences.id) private var preferencesQuery: [AppPreferences]

    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings = false
    @State private var settingsSheetID = UUID()
    @State private var settingsSheetCoordinator = SettingsSheetCoordinator()
    @State private var sosError: String?

    private var preferences: AppPreferences? { preferencesQuery.first }

    private var appLocale: Locale {
        Locale(identifier: preferences?.preferredLanguageCode ?? locale.identifier)
    }

    private var gridColumns: [GridItem] {
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: columnCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.string("home.title", locale: appLocale))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(themeManager.colors.primaryText)
                        .padding(.horizontal, 2)
                        .accessibilityAddTraits(.isHeader)

                    if favorites.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 14) {
                            ForEach(favorites) { contact in
                                ContactCardView(contact: contact, colors: themeManager.colors) {
                                    guard let prefs = preferences else { return }
                                    viewModel.initiateCall(
                                        for: contact,
                                        preferences: prefs,
                                        services: services,
                                        locale: appLocale
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.automatic)
            .background {
                themeManager.colors.background
                    .ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let prefs = preferences {
                    EmergencySOSView(
                        colors: themeManager.colors,
                        isEnabled: prefs.sosEnabled && !prefs.sanitizedEmergencyPhoneNumber.isEmpty,
                        voicePromptsEnabled: prefs.voicePromptsEnabled,
                        languageCode: prefs.preferredLanguageCode,
                        emergencyNumber: prefs.sanitizedEmergencyPhoneNumber,
                        onEmergencyCallResult: { msg in
                            sosError = msg
                        }
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        themeManager.colors.accessibilityEmphasis
                            ? AnyShapeStyle(themeManager.colors.background)
                            : AnyShapeStyle(.regularMaterial)
                    )
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openSettings()
                    } label: {
                        Label(L10n.string("settings.title", locale: appLocale), systemImage: "gearshape.fill")
                            .font(.title2.weight(.semibold))
                            .labelStyle(.iconOnly)
                            .padding(10)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(L10n.string("a11y.settings_button", locale: appLocale)))
                    .accessibilityHint(Text(L10n.string("a11y.settings_hint", locale: appLocale)))
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                settingsSheetCoordinator.revertUncommittedChanges()
            }) {
                SettingsView(sheetCoordinator: settingsSheetCoordinator)
                    .environment(\.locale, appLocale)
                    .id(settingsSheetID)
            }
            .onChange(of: showSettings) { _, isPresented in
                if isPresented {
                    settingsSheetID = UUID()
                }
            }
            .alert(
                L10n.string("error.title", locale: appLocale),
                isPresented: Binding(
                    get: { viewModel.lastErrorMessage != nil },
                    set: { if !$0 { viewModel.clearError() } }
                ),
                actions: {
                    Button(L10n.string("common.ok", locale: appLocale), role: .cancel) {
                        viewModel.clearError()
                    }
                },
                message: {
                    Text(viewModel.lastErrorMessage ?? "")
                }
            )
            .alert(
                L10n.string("error.title", locale: appLocale),
                isPresented: Binding(
                    get: { sosError != nil },
                    set: { if !$0 { sosError = nil } }
                ),
                actions: {
                    Button(L10n.string("common.ok", locale: appLocale), role: .cancel) {
                        sosError = nil
                    }
                },
                message: {
                    Text(sosError ?? "")
                }
            )
        }
        .environment(\.locale, appLocale)
    }

    private func openSettings() {
        showSettings = true
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("home.empty.title", locale: appLocale))
                .font(.title2.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Text(L10n.string("home.empty.detail", locale: appLocale))
                .font(.title3)
                .foregroundStyle(themeManager.colors.secondaryText)
            Button {
                openSettings()
            } label: {
                Text(L10n.string("home.empty.action", locale: appLocale))
                    .font(.title3.weight(.bold))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .background(themeManager.colors.primaryButton)
                    .foregroundStyle(themeManager.colors.onPrimaryButton)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityLabel(Text(L10n.string("home.empty.action", locale: appLocale)))
            .accessibilityHint(Text(L10n.string("a11y.settings_hint", locale: appLocale)))
            .padding(.top, 8)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    HomeView()
        .environment(\.appServices, AppServices())
        .environmentObject(ThemeManager())
        .environment(\.locale, Locale(identifier: "en"))
        .modelContainer(PreviewSampleData.container)
}
