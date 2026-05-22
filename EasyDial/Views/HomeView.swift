//
//  HomeView.swift
//  EasyDial
//
//  Primary surface: favorites grid (2 columns on iPhone, 3 on iPad) + persistent SOS bar.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(\.appServices) private var services
    @Environment(\.locale) private var locale
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: AppStore

    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings = false
    @State private var settingsSheetID = UUID()
    @State private var settingsSheetCoordinator = SettingsSheetCoordinator()
    @State private var sosError: String?
    @State private var showContactPicker = false
    @State private var importNotice: String?

    private var favorites: [FavoriteContact] { store.favorites }
    private var preferences: AppPreferences? { store.preferences }
    private var favoriteLimit: Int { AppConfiguration.shared.maxTotalFavoriteContacts }
    private var importValidator: FavoriteImportValidator {
        FavoriteImportValidator(favorites: favorites, limit: favoriteLimit)
    }
    private var isAtFavoriteLimit: Bool { !importValidator.canAdd }
    private var excludedContactIdentifiers: Set<String> { importValidator.excludedContactIDs }
    private var excludedSanitizedPhones: Set<String> { importValidator.excludedPhones }

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
                                ContactCardView(
                                    contact: contact,
                                    photoData: store.photoCache[contact.id],
                                    colors: themeManager.colors
                                ) {
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
                        Task { await beginAddFromContacts() }
                    } label: {
                        Label(L10n.string("settings.contacts.add", locale: appLocale), systemImage: "person.badge.plus")
                            .font(.title2.weight(.semibold))
                            .labelStyle(.iconOnly)
                            .padding(10)
                            .contentShape(Rectangle())
                    }
                    .disabled(isAtFavoriteLimit)
                    .accessibilityLabel(Text(L10n.string("settings.contacts.add", locale: appLocale)))
                    .accessibilityHint(
                        Text(
                            isAtFavoriteLimit
                                ? L10n.string("favorites.add.disabled_hint", locale: appLocale)
                                : L10n.string("a11y.add_contact_hint", locale: appLocale)
                        )
                    )
                }
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
            .contactPicker(
                isPresented: $showContactPicker,
                excludedContactIdentifiers: excludedContactIdentifiers,
                excludedSanitizedPhones: excludedSanitizedPhones,
                onCancel: { showContactPicker = false },
                onDuplicate: {
                    showContactPicker = false
                    let message = L10n.string("add.error.duplicate", locale: appLocale)
                    importNotice = message
                    UIAccessibility.post(notification: .announcement, argument: message)
                },
                onPick: { selection in
                    showContactPicker = false
                    handleContactPicked(selection)
                }
            )
            .onChange(of: showSettings) { _, isPresented in
                if isPresented { settingsSheetID = UUID() }
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
                message: { Text(viewModel.lastErrorMessage ?? "") }
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
                message: { Text(sosError ?? "") }
            )
            .alert(
                L10n.string("error.title", locale: appLocale),
                isPresented: Binding(
                    get: { importNotice != nil },
                    set: { if !$0 { importNotice = nil } }
                ),
                actions: {
                    Button(L10n.string("common.ok", locale: appLocale), role: .cancel) {
                        importNotice = nil
                    }
                },
                message: { Text(importNotice ?? "") }
            )
        }
        .environment(\.locale, appLocale)
    }

    private func openSettings() { showSettings = true }

    private func beginAddFromContacts() async {
        importNotice = nil
        guard importValidator.canAdd else {
            await MainActor.run {
                importNotice = L10n.string("favorites.add.disabled_hint", locale: appLocale)
            }
            return
        }
        if !services.permissions.canReadContacts() {
            let granted = await services.permissions.requestContactsAccess()
            guard granted else {
                await MainActor.run {
                    importNotice = L10n.string("setup.permissions.denied", locale: appLocale)
                }
                return
            }
        }
        await MainActor.run { showContactPicker = true }
    }

    @MainActor
    private func handleContactPicked(_ selection: ContactPickerSelection) {
        if let issue = FavoriteContactImporter.addFavorite(
            from: selection,
            favorites: favorites,
            limit: favoriteLimit,
            contacts: services.contacts,
            locale: appLocale,
            store: store
        ) {
            let message = issue.localizedMessage(locale: appLocale, favoriteLimit: favoriteLimit)
            importNotice = message
            if issue == .duplicateContact || issue == .duplicatePhone {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        } else {
            importNotice = nil
        }
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
        .environmentObject(AppStore.preview)
        .environment(\.locale, Locale(identifier: "en"))
}
