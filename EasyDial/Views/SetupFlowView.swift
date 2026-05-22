//
//  SetupFlowView.swift
//  EasyDial
//
//  First-run setup: permissions → picks → labels → photos → theme → language → finish.
//

import PhotosUI
import SwiftUI

struct SetupFlowView: View {
    @Environment(\.appServices) private var services
    @Environment(\.locale) private var locale
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: AppStore

    @StateObject private var setupVM = SetupViewModel()

    private var preferences: AppPreferences? { store.preferences }
    private var setupPickCap: Int { AppConfiguration.shared.maxFavoriteContactsDuringSetup }

    @State private var setupPickLimitNotice: String?
    @State private var setupSearchQuery = ""

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                VStack(spacing: 14) {
                    segmentedProgressBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    ScrollView {
                        setupContentCard {
                            VStack(alignment: .leading, spacing: 18) {
                                switch setupVM.step {
                                case .permissions:   permissionsStep
                                case .pickContacts:  pickContactsStep
                                case .relationships: relationshipsStep
                                case .photos:        photosStep
                                case .theme:         themeStep
                                case .language:      languageStep
                                case .finish:        finishStep
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    if setupVM.step != .permissions {
                        navigationButtons
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle(Text(L10n.string("setup.nav_title", locale: locale)))
            .onChange(of: setupVM.step) { _, step in
                if step == .pickContacts {
                    loadImportsIfNeeded()
                    setupPickLimitNotice = nil
                    setupSearchQuery = ""
                }
            }
        }
    }

    private var segmentedProgressBar: some View {
        let total = SetupViewModel.Step.ordered.count
        let filled = min(setupVM.step.rawValue + 1, total)
        return HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index < filled ? themeManager.colors.primaryButton : themeManager.colors.divider)
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.string("a11y.setup_progress", locale: locale)))
    }

    @ViewBuilder
    private func setupContentCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shadowColor = themeManager.colors.accessibilityEmphasis
            ? Color.clear
            : Color.black.opacity(0.08)
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(themeManager.colors.cardBackground)
                    .shadow(color: shadowColor, radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(themeManager.colors.divider, lineWidth: themeManager.colors.cardStrokeWidth)
            )
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("setup.permissions.title", locale: locale))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.string("setup.permissions.body", locale: locale))
                .font(.title3)
                .foregroundStyle(themeManager.colors.secondaryText)

            if setupVM.permissionDenied {
                Text(L10n.string("setup.permissions.denied", locale: locale))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.emergency)
                    .accessibilityAddTraits(.isStaticText)

                Button(L10n.string("setup.permissions.open_settings", locale: locale)) {
                    services.permissions.openAppSettings()
                }
                .font(.title3.weight(.bold))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(themeManager.colors.cardBackground)
                .foregroundStyle(themeManager.colors.primaryButton)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeManager.colors.divider))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(L10n.string("setup.permissions.cta", locale: locale)) {
                Task {
                    let granted = await services.permissions.requestContactsAccess()
                    await MainActor.run {
                        if granted {
                            setupVM.permissionDenied = false
                            loadImports()
                            setupVM.advance()
                        } else {
                            setupVM.permissionDenied = true
                        }
                    }
                }
            }
            .font(.title3.weight(.bold))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(themeManager.colors.primaryButton)
            .foregroundStyle(themeManager.colors.onPrimaryButton)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHint(Text(L10n.string("setup.permissions.cta_hint", locale: locale)))
        }
    }

    private var filteredSetupContacts: [ImportedContact] {
        let query = setupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return setupVM.importedContacts }
        return setupVM.importedContacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    private var pickContactsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("setup.pick.title", locale: locale))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Text(
                String(
                    format: L10n.string("setup.pick.body", locale: locale),
                    locale: locale,
                    arguments: [Int64(setupPickCap)]
                )
            )
            .font(.title3)
            .foregroundStyle(themeManager.colors.secondaryText)

            if let notice = setupPickLimitNotice {
                Text(notice)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.primaryButton)
                    .accessibilityAddTraits(.isStaticText)
            }
            if let err = setupVM.loadError {
                Text(err)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.emergency)
            }

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(themeManager.colors.secondaryText)
                    .accessibilityHidden(true)
                TextField(L10n.string("add.search", locale: locale), text: $setupSearchQuery)
                    .font(.body)
                    .foregroundStyle(themeManager.colors.primaryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel(Text(L10n.string("add.search", locale: locale)))
                if !setupSearchQuery.isEmpty {
                    Button {
                        setupSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(themeManager.colors.secondaryText)
                    }
                    .accessibilityLabel(Text(L10n.string("common.cancel", locale: locale)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(themeManager.colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.colors.divider))

            if filteredSetupContacts.isEmpty && !setupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(L10n.string("setup.pick.no_results", locale: locale))
                    .font(.body)
                    .foregroundStyle(themeManager.colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSetupContacts) { contact in
                        Button {
                            if setupVM.selectedImports.contains(contact.id) {
                                setupVM.selectedImports.remove(contact.id)
                                setupPickLimitNotice = nil
                            } else if setupVM.selectedImports.count >= setupPickCap {
                                setupPickLimitNotice = String(
                                    format: L10n.string("setup.pick.max_reached", locale: locale),
                                    locale: locale,
                                    arguments: [Int64(setupPickCap)]
                                )
                            } else {
                                setupVM.selectedImports.insert(contact.id)
                                setupPickLimitNotice = nil
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Image(
                                    systemName: setupVM.selectedImports.contains(contact.id)
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                                .font(.title2.weight(.bold))
                                .foregroundStyle(themeManager.colors.primaryButton)
                                .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.displayName)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(themeManager.colors.primaryText)
                                    if let phone = contact.phoneNumbers.first {
                                        Text(phone)
                                            .font(.body)
                                            .foregroundStyle(themeManager.colors.secondaryText)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text(contact.displayName))
                        .accessibilityHint(Text(L10n.string("setup.pick.row_hint", locale: locale)))
                        .accessibilityAddTraits(.isButton)

                        if contact.id != filteredSetupContacts.last?.id {
                            Divider()
                                .background(themeManager.colors.divider)
                        }
                    }
                }
            }
        }
    }

    private var relationshipsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("setup.relationships.title", locale: locale))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Text(L10n.string("setup.relationships.body_phone_only", locale: locale))
                .font(.title3)
                .foregroundStyle(themeManager.colors.secondaryText)

            ForEach(setupVM.drafts) { draft in
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.displayName)
                        .font(.title3.weight(.bold))
                    ThemedTextField(
                        prompt: L10n.string("editor.phone", locale: locale),
                        text: Binding(
                            get: { setupVM.drafts.first(where: { $0.id == draft.id })?.phoneNumber ?? "" },
                            set: { setupVM.updateDraft(id: draft.id, phone: $0) }
                        ),
                        colors: themeManager.colors,
                        keyboardType: .phonePad
                    )
                    .font(.title3)
                    .padding(12)
                    .background(themeManager.colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.colors.divider))
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("setup.photos.title", locale: locale))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Text(L10n.string("setup.photos.body", locale: locale))
                .font(.title3)
                .foregroundStyle(themeManager.colors.secondaryText)
            ForEach(setupVM.drafts) { draft in
                SetupPhotoRow(draftId: draft.id, setupVM: setupVM, colors: themeManager.colors)
            }
        }
    }

    private var themeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("setup.theme.title", locale: locale))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Picker(L10n.string("settings.theme", locale: locale), selection: Binding(
                get: { preferences?.theme ?? .light },
                set: { newValue in
                    try? store.updatePreferences { $0.theme = newValue }
                    themeManager.apply(theme: newValue)
                }
            )) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.localizedTitleKey).tag(theme)
                }
            }
            .pickerStyle(.inline)
            .font(.title3.weight(.semibold))
        }
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("setup.language.title", locale: locale))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Picker(L10n.string("settings.language", locale: locale), selection: Binding(
                get: {
                    AppLanguage.resolved(
                        from: preferences?.preferredLanguageCode ?? AppLanguage.english.rawValue
                    )
                },
                set: { lang in
                    try? store.updatePreferences { $0.preferredLanguageCode = lang.rawValue }
                }
            )) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.nativeTitle).tag(lang)
                }
            }
            .pickerStyle(.inline)
            .font(.title3.weight(.semibold))
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("setup.finish.title", locale: locale))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(themeManager.colors.primaryText)
            Text(L10n.string("setup.finish.body", locale: locale))
                .font(.title3)
                .foregroundStyle(themeManager.colors.secondaryText)

            if let err = setupVM.loadError {
                Text(err)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.emergency)
                    .accessibilityAddTraits(.isStaticText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(setupVM.drafts) { draft in
                    Text(
                        String(
                            format: L10n.string("setup.finish.item", locale: locale),
                            locale: locale,
                            arguments: [draft.displayName]
                        )
                    )
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(themeManager.colors.primaryText)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if setupVM.step != .permissions {
                Button(L10n.string("common.back", locale: locale)) {
                    setupVM.goBack()
                }
                .font(.title3.weight(.bold))
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(themeManager.colors.cardBackground)
                .foregroundStyle(themeManager.colors.primaryText)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeManager.colors.divider))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(nextTitle) { advance() }
                .font(.title3.weight(.bold))
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    canContinue
                        ? themeManager.colors.primaryButton
                        : themeManager.colors.secondaryText.opacity(0.35)
                )
                .foregroundStyle(themeManager.colors.onPrimaryButton)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(!canContinue)
                .accessibilityHint(Text(L10n.string("a11y.setup_next_hint", locale: locale)))
        }
    }

    private var nextTitle: String {
        setupVM.step == .finish
            ? L10n.string("setup.finish.primary", locale: locale)
            : L10n.string("common.next", locale: locale)
    }

    private var canContinue: Bool {
        switch setupVM.step {
        case .permissions: return true
        case .pickContacts: return !setupVM.selectedImports.isEmpty
        case .relationships:
            return setupVM.drafts.allSatisfy {
                !CallService.sanitizePhone($0.phoneNumber).isEmpty
            }
        case .photos, .theme, .language, .finish: return true
        }
    }

    private func advance() {
        switch setupVM.step {
        case .permissions: break
        case .pickContacts: setupVM.rebuildDraftsFromSelection(); setupVM.advance()
        case .relationships, .photos, .theme, .language: setupVM.advance()
        case .finish: finishSetup()
        }
    }

    private func finishSetup() {
        setupVM.loadError = nil
        do {
            try setupVM.commitDrafts(store: store, locale: locale)
        } catch {
            setupVM.loadError = L10n.string("error.save_failed", locale: locale)
        }
    }

    private func loadImportsIfNeeded() {
        guard setupVM.importedContacts.isEmpty else { return }
        loadImports()
    }

    private func loadImports() {
        do {
            setupVM.importedContacts = try services.contacts.fetchContacts(locale: locale)
            setupVM.loadError = nil
        } catch {
            setupVM.loadError = L10n.string("error.contacts_load", locale: locale)
        }
    }

}

// MARK: - SetupPhotoRow

private struct SetupPhotoRow: View {
    let draftId: UUID
    @ObservedObject var setupVM: SetupViewModel
    let colors: ThemeColors

    @Environment(\.locale) private var locale
    @State private var item: PhotosPickerItem?

    private var draft: SetupDraftContact? {
        setupVM.drafts.first { $0.id == draftId }
    }

    var body: some View {
        if let draft {
            VStack(alignment: .leading, spacing: 12) {
                Text(draft.displayName)
                    .font(.title3.weight(.bold))

                HStack(alignment: .center, spacing: 16) {
                    if let data = draft.photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(colors.divider, lineWidth: 1)
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                Text(
                                    String(
                                        format: L10n.string("setup.photos.preview_a11y", locale: locale),
                                        locale: locale,
                                        arguments: [draft.displayName]
                                    )
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(colors.background)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundStyle(colors.secondaryText)
                            }
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        PhotosPicker(
                            selection: $item,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(
                                draft.photoData == nil
                                    ? L10n.string("setup.photos.choose", locale: locale)
                                    : L10n.string("setup.photos.change", locale: locale),
                                systemImage: "photo"
                            )
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(colors.primaryButton.opacity(0.15))
                            .foregroundStyle(colors.primaryButton)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityHint(
                            Text(L10n.string("setup.photos.a11y_hint", locale: locale))
                        )

                        if draft.photoData != nil {
                            Button(role: .destructive) {
                                item = nil
                                setupVM.updatePhoto(for: draftId, data: nil)
                            } label: {
                                Text(L10n.string("setup.photos.remove", locale: locale))
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(colors.emergency.opacity(0.15))
                                    .foregroundStyle(colors.emergency)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onChange(of: item) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            setupVM.updatePhoto(for: draftId, data: data)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SetupFlowView()
        .environment(\.appServices, AppServices())
        .environmentObject(ThemeManager())
        .environmentObject(AppStore.preview)
        .environment(\.locale, Locale(identifier: "en"))
}
