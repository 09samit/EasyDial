//
//  FavoriteContactsView.swift
//  EasyDial
//
//  Add favorites from Contacts, reorder, edit, and remove.
//

import SwiftUI
import UIKit

struct FavoriteContactsView: View {
    @Environment(\.appServices) private var services
    @Environment(\.locale) private var locale
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: AppStore

    @State private var showContactPicker = false
    @State private var saveError: String?
    @State private var importNotice: String?

    private var favorites: [FavoriteContact] { store.favorites }
    private var favoriteLimit: Int { AppConfiguration.shared.maxTotalFavoriteContacts }
    private var importValidator: FavoriteImportValidator {
        FavoriteImportValidator(favorites: favorites, limit: favoriteLimit)
    }
    private var isAtFavoriteLimit: Bool { !importValidator.canAdd }
    private var excludedContactIdentifiers: Set<String> { importValidator.excludedContactIDs }
    private var excludedSanitizedPhones: Set<String> { importValidator.excludedPhones }

    var body: some View {
        List {
            if let importNotice {
                Section {
                    Text(importNotice)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeManager.colors.emergency)
                }
            }
            if let saveError {
                Section {
                    Text(saveError)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeManager.colors.emergency)
                }
            }

            Section {
                ForEach(favorites) { contact in
                    NavigationLink {
                        EditFavoriteView(contact: contact)
                            .environment(\.locale, locale)
                    } label: {
                        favoriteRow(contact)
                    }
                    .listRowBackground(themeManager.colors.groupedSurface)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } header: {
                Text(L10n.string("settings.section.favorites", locale: locale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themeManager.colors.secondaryText)
            } footer: {
                if isAtFavoriteLimit {
                    Text(L10n.string("favorites.add.disabled_hint", locale: locale))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeManager.colors.emergency)
                } else {
                    Text(L10n.string("settings.reorder.help", locale: locale))
                        .font(.body)
                        .foregroundStyle(themeManager.colors.secondaryText)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(themeManager.colors.background)
        .scrollContentBackground(.hidden)
        .toolbarBackground(themeManager.colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(Text(L10n.string("favorites.title", locale: locale)))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
                    .font(.body.weight(.semibold))
                    .accessibilityLabel(Text(L10n.string("a11y.edit_button", locale: locale)))
                    .accessibilityHint(Text(L10n.string("a11y.edit_hint", locale: locale)))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await beginAddFromContacts() }
                } label: {
                    Label(L10n.string("settings.contacts.add", locale: locale), systemImage: "person.badge.plus")
                        .font(.body.weight(.semibold))
                }
                .disabled(isAtFavoriteLimit)
                .accessibilityHint(
                    Text(
                        isAtFavoriteLimit
                            ? L10n.string("favorites.add.disabled_hint", locale: locale)
                            : L10n.string("a11y.add_contact_hint", locale: locale)
                    )
                )
            }
        }
        .contactPicker(
            isPresented: $showContactPicker,
            excludedContactIdentifiers: excludedContactIdentifiers,
            excludedSanitizedPhones: excludedSanitizedPhones,
            onCancel: { showContactPicker = false },
            onDuplicate: {
                showContactPicker = false
                let message = L10n.string("add.error.duplicate", locale: locale)
                importNotice = message
                UIAccessibility.post(notification: .announcement, argument: message)
            },
            onPick: { selection in
                showContactPicker = false
                handleContactPicked(selection)
            }
        )
    }

    @ViewBuilder
    private func favoriteRow(_ contact: FavoriteContact) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(contact.displayName)
                .font(.title3.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Text(contact.phoneNumber)
                .font(.body.monospacedDigit())
                .foregroundStyle(themeManager.colors.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private func beginAddFromContacts() async {
        importNotice = nil
        guard importValidator.canAdd else { return }
        if !services.permissions.canReadContacts() {
            let granted = await services.permissions.requestContactsAccess()
            guard granted else {
                await MainActor.run {
                    importNotice = L10n.string("setup.permissions.denied", locale: locale)
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
            locale: locale,
            store: store
        ) {
            importNotice = issue.localizedMessage(locale: locale, favoriteLimit: favoriteLimit)
            if issue == .duplicateContact || issue == .duplicatePhone {
                UIAccessibility.post(notification: .announcement, argument: importNotice)
            }
        } else {
            importNotice = nil
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        do {
            try store.moveFavorites(from: source, to: destination)
            saveError = nil
        } catch {
            saveError = L10n.string("error.save_failed", locale: locale)
        }
    }

    private func delete(at offsets: IndexSet) {
        let snapshot = favorites
        do {
            for index in offsets {
                guard snapshot.indices.contains(index) else { continue }
                try store.deleteFavorite(id: snapshot[index].id)
            }
            saveError = nil
        } catch {
            saveError = L10n.string("error.save_failed", locale: locale)
        }
    }
}

#Preview {
    NavigationStack {
        FavoriteContactsView()
    }
    .environment(\.appServices, AppServices())
    .environmentObject(ThemeManager())
    .environmentObject(AppStore.preview)
    .environment(\.locale, Locale(identifier: "en"))
}
