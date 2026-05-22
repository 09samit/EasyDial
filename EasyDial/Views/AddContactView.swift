//
//  AddContactView.swift
//  EasyDial
//
//  Adds a favorite via the system Contacts picker and confirms phone number.
//

import Contacts
import SwiftUI

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var services
    @Environment(\.locale) private var locale
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: AppStore

    @State private var showContactPicker = false
    @State private var permissionDenied = false
    @State private var prepareError: String?

    @State private var selected: ImportedContact?
    @State private var pickedPhone: String = ""
    @State private var duplicateError: String?
    @State private var pickNotice: String?

    @State private var showNewContact = false
    @State private var isPreparingPicker = false
    @State private var didAutoPresentPicker = false

    private var favorites: [FavoriteContact] { store.favorites }
    private var favoriteLimit: Int { AppConfiguration.shared.maxTotalFavoriteContacts }
    private var importValidator: FavoriteImportValidator {
        FavoriteImportValidator(favorites: favorites, limit: favoriteLimit)
    }
    private var isAtFavoriteLimit: Bool { !importValidator.canAdd }
    private var excludedContactIdentifiers: Set<String> { importValidator.excludedContactIDs }
    private var excludedSanitizedPhones: Set<String> { importValidator.excludedPhones }

    var body: some View {
        Group {
            if let prepareError {
                permissionOrErrorContent(message: prepareError, showSettings: permissionDenied)
            } else if isAtFavoriteLimit {
                Text(
                    String(
                        format: L10n.string("add.error.max_favorites", locale: locale),
                        locale: locale,
                        arguments: [Int64(favoriteLimit)]
                    )
                )
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            } else if isPreparingPicker {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                addActionsContent
            }
        }
        .navigationTitle(Text(L10n.string("add.title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string("common.cancel", locale: locale)) { dismiss() }
                    .font(.body.weight(.semibold))
            }
            if !isAtFavoriteLimit, prepareError == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pickNotice = nil
                        showNewContact = true
                    } label: {
                        Label(
                            L10n.string("add.new_contact", locale: locale),
                            systemImage: "person.crop.circle.badge.plus"
                        )
                    }
                    .accessibilityHint(Text(L10n.string("add.new_contact_hint", locale: locale)))
                }
            }
        }
        .contactPicker(
            isPresented: $showContactPicker,
            excludedContactIdentifiers: excludedContactIdentifiers,
            excludedSanitizedPhones: excludedSanitizedPhones,
            onCancel: {
                showContactPicker = false
                dismiss()
            },
            onDuplicate: {
                showContactPicker = false
                pickNotice = L10n.string("add.error.duplicate", locale: locale)
            },
            onPick: { selection in
                showContactPicker = false
                handlePickerSelection(selection)
            }
        )
        .sheet(isPresented: $showNewContact) {
            NewContactComposer { contact in
                showNewContact = false
                handleNewContactSaved(contact)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selected) { contact in
            confirmFavoriteSheet(contact: contact)
        }
        .task(id: favorites.count) {
            guard !didAutoPresentPicker else { return }
            didAutoPresentPicker = true
            await prepareContactPicker()
        }
    }

    @ViewBuilder
    private var addActionsContent: some View {
        VStack(spacing: 20) {
            if let pickNotice {
                Text(pickNotice)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.emergency)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button {
                pickNotice = nil
                Task { await presentContactPicker() }
            } label: {
                Label(
                    L10n.string("add.open_contacts", locale: locale),
                    systemImage: "person.crop.circle"
                )
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .accessibilityHint(Text(L10n.string("a11y.add_contact_hint", locale: locale)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func permissionOrErrorContent(message: String, showSettings: Bool) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if showSettings {
                Button(L10n.string("setup.permissions.open_settings", locale: locale)) {
                    services.permissions.openAppSettings()
                }
                .font(.title3.weight(.bold))
            }
        }
        .padding()
    }

    @ViewBuilder
    private func confirmFavoriteSheet(contact: ImportedContact) -> some View {
        NavigationStack {
            Form {
                if let duplicateError {
                    Text(duplicateError)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeManager.colors.emergency)
                }
                if isAtFavoriteLimit {
                    Text(
                        String(
                            format: L10n.string("add.error.max_favorites", locale: locale),
                            locale: locale,
                            arguments: [Int64(favoriteLimit)]
                        )
                    )
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.emergency)
                }
                Section {
                    Text(contact.displayName)
                        .font(.title3.weight(.bold))
                    if contact.phoneNumbers.count > 1 {
                        Picker(L10n.string("add.phone_picker", locale: locale), selection: $pickedPhone) {
                            ForEach(contact.phoneNumbers, id: \.self) { phone in
                                Text(phone).tag(phone)
                            }
                        }
                        .font(.body.weight(.semibold))
                    } else {
                        ThemedTextField(
                            prompt: L10n.string("editor.phone", locale: locale),
                            text: $pickedPhone,
                            colors: themeManager.colors,
                            keyboardType: .phonePad
                        )
                        .font(.title3)
                    }
                } footer: {
                    Text(L10n.string("add.footer", locale: locale))
                        .font(.body)
                }
            }
            .navigationTitle(Text(L10n.string("add.confirm", locale: locale)))
            .onAppear { syncPickedPhone(for: contact) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel", locale: locale)) {
                        selected = nil
                        duplicateError = nil
                        Task { await presentContactPicker() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save", locale: locale)) {
                        save(contact: contact)
                    }
                    .font(.body.weight(.bold))
                    .disabled(!canSave(contact: contact))
                }
            }
            .environment(\.locale, locale)
        }
    }

    private func syncPickedPhone(for contact: ImportedContact) {
        let phones = contact.phoneNumbers
        guard !phones.isEmpty else { pickedPhone = ""; return }
        if phones.contains(pickedPhone) { return }
        pickedPhone = phones[0]
    }

    private func canSave(contact: ImportedContact) -> Bool {
        guard importValidator.canAdd else { return false }
        let sanitized = CallService.sanitizePhone(
            pickedPhone.isEmpty ? (contact.phoneNumbers.first ?? "") : pickedPhone
        )
        guard !sanitized.isEmpty else { return false }
        return importValidator.issue(contactID: contact.id, sanitizedPhone: sanitized) == nil
    }

    private func prepareContactPicker() async {
        guard importValidator.canAdd else { return }
        await MainActor.run {
            isPreparingPicker = true
            prepareError = nil
            permissionDenied = false
        }
        if !services.permissions.canReadContacts() {
            let granted = await services.permissions.requestContactsAccess()
            guard granted else {
                await MainActor.run {
                    permissionDenied = true
                    prepareError = L10n.string("setup.permissions.denied", locale: locale)
                    isPreparingPicker = false
                }
                return
            }
        }
        await MainActor.run {
            isPreparingPicker = false
            guard importValidator.canAdd else { return }
            showContactPicker = true
        }
    }

    private func presentContactPicker() async {
        guard importValidator.canAdd else {
            await MainActor.run {
                pickNotice = String(
                    format: L10n.string("add.error.max_favorites", locale: locale),
                    locale: locale,
                    arguments: [Int64(favoriteLimit)]
                )
            }
            return
        }
        if services.permissions.canReadContacts() {
            await MainActor.run { showContactPicker = true }
        } else {
            await prepareContactPicker()
        }
    }

    @MainActor
    private func handlePickerSelection(_ selection: ContactPickerSelection) {
        guard importValidator.canAdd else {
            pickNotice = message(for: .atFavoriteLimit)
            return
        }
        let contact: CNContact
        let preselectedPhone: String?
        switch selection {
        case .contact(let picked):
            contact = picked; preselectedPhone = nil
        case .phone(let picked, let number):
            contact = picked; preselectedPhone = number
        }
        guard let imported = services.contacts.resolveImport(
            pickerContact: contact,
            preselectedPhone: preselectedPhone,
            locale: locale
        ) else {
            pickNotice = message(for: .noDialablePhone)
            return
        }
        let initialPhone = imported.phoneNumbers.first ?? ""
        let sanitized = CallService.sanitizePhone(initialPhone)
        if let issue = importValidator.issue(contactID: imported.id, sanitizedPhone: sanitized) {
            pickNotice = message(for: issue)
            return
        }
        pickNotice = nil
        selected = imported
        pickedPhone = initialPhone
        duplicateError = nil
    }

    @MainActor
    private func handleNewContactSaved(_ contact: CNContact?) {
        guard let contact else { return }
        guard importValidator.canAdd else {
            pickNotice = message(for: .atFavoriteLimit)
            return
        }
        guard let imported = services.contacts.resolveImport(pickerContact: contact, locale: locale) else {
            pickNotice = message(for: .noDialablePhone)
            return
        }
        let initialPhone = imported.phoneNumbers.first ?? ""
        let sanitized = CallService.sanitizePhone(initialPhone)
        if let issue = importValidator.issue(contactID: imported.id, sanitizedPhone: sanitized) {
            pickNotice = message(for: issue)
            return
        }
        pickNotice = nil
        selected = imported
        pickedPhone = initialPhone
        duplicateError = nil
    }

    private func message(for issue: FavoriteImportIssue) -> String {
        switch issue {
        case .atFavoriteLimit:
            return String(
                format: L10n.string("add.error.max_favorites", locale: locale),
                locale: locale,
                arguments: [Int64(favoriteLimit)]
            )
        case .duplicateContact, .duplicatePhone:
            return L10n.string("add.error.duplicate", locale: locale)
        case .noDialablePhone:
            return L10n.string("add.error.no_phone", locale: locale)
        case .saveFailed:
            return L10n.string("error.save_failed", locale: locale)
        }
    }

    private func save(contact: ImportedContact) {
        guard importValidator.canAdd else {
            duplicateError = message(for: .atFavoriteLimit)
            return
        }
        let sanitized = CallService.sanitizePhone(
            pickedPhone.isEmpty ? (contact.phoneNumbers.first ?? "") : pickedPhone
        )
        guard !sanitized.isEmpty else {
            duplicateError = message(for: .noDialablePhone)
            return
        }
        if let issue = importValidator.issue(contactID: contact.id, sanitizedPhone: sanitized) {
            duplicateError = message(for: issue)
            return
        }
        let nextOrder = (favorites.map(\.sortOrder).max() ?? -1) + 1
        let favorite = FavoriteContact(
            sortOrder: nextOrder,
            displayName: contact.displayName,
            relationshipLabel: FavoriteContact.hiddenRelationshipLabel,
            phoneNumber: sanitized,
            cnContactIdentifier: contact.id
        )
        do {
            try store.insertFavorite(favorite, photoData: contact.thumbnailImageData)
            dismiss()
        } catch {
            duplicateError = L10n.string("error.save_failed", locale: locale)
        }
    }
}

#Preview {
    NavigationStack {
        AddContactView()
    }
    .environment(\.appServices, AppServices())
    .environmentObject(ThemeManager())
    .environmentObject(AppStore.preview)
    .environment(\.locale, Locale(identifier: "en"))
}
