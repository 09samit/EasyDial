//
//  SettingsView.swift
//  EasyDial
//
//  App settings: accessibility, SOS, and favorites; edits are staged until Done.
//

import SwiftUI

/// Routes sheet-level dismiss to staged-settings revert (not fired on in-settings navigation push).
@MainActor
final class SettingsSheetCoordinator {
    private var revertAction: (() -> Void)?

    func setRevertAction(_ action: @escaping () -> Void) {
        revertAction = action
    }

    func revertUncommittedChanges() {
        revertAction?()
    }
}

private struct SettingsRevertRegistration: View {
    let coordinator: SettingsSheetCoordinator
    let onRevert: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear { coordinator.setRevertAction(onRevert) }
    }
}

/// Staged settings; applied to the store only when the user taps Done.
private struct SettingsDraft: Equatable {
    var themeRaw: String
    var preferredLanguageCode: String
    var dynamicTypeSizeRaw: String?
    var voicePromptsEnabled: Bool
    var sosEnabled: Bool
    var emergencyPhoneNumber: String

    init(from preferences: AppPreferences) {
        themeRaw = preferences.themeRaw
        preferredLanguageCode = preferences.preferredLanguageCode
        dynamicTypeSizeRaw = preferences.dynamicTypeSizeRaw
        voicePromptsEnabled = preferences.voicePromptsEnabled
        sosEnabled = preferences.sosEnabled
        emergencyPhoneNumber = preferences.emergencyPhoneNumber
    }

    func write(to prefs: inout AppPreferences) {
        prefs.themeRaw = themeRaw
        prefs.preferredLanguageCode = preferredLanguageCode
        prefs.dynamicTypeSizeRaw = dynamicTypeSizeRaw
        prefs.voicePromptsEnabled = voicePromptsEnabled
        prefs.sosEnabled = sosEnabled
        prefs.emergencyPhoneNumber = emergencyPhoneNumber
    }

    func validatedForSave(locale: Locale) -> (draft: SettingsDraft, error: String?) {
        var copy = self
        copy.emergencyPhoneNumber = CallService.sanitizePhone(emergencyPhoneNumber)
        if copy.sosEnabled && copy.emergencyPhoneNumber.isEmpty {
            let trimmed = emergencyPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return (copy, L10n.string("validation.emergency_phone_invalid", locale: locale))
            }
            return (copy, L10n.string("validation.emergency_phone_required", locale: locale))
        }
        return (copy, nil)
    }
}

struct SettingsView: View {
    var sheetCoordinator: SettingsSheetCoordinator?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: AppStore

    @State private var draft: SettingsDraft?
    @State private var snapshot: SettingsDraft?
    @State private var committed = false
    @State private var selectedTheme: AppTheme = .light
    @State private var selectedLanguage: AppLanguage = .english
    @State private var commitValidationMessage: String?
    @State private var showResetSetupConfirm = false
    @State private var resetSetupError: String?

    private var preferences: AppPreferences? { store.preferences }

    private var previewLocale: Locale {
        Locale(identifier: draft?.preferredLanguageCode ?? preferences?.preferredLanguageCode ?? "en")
    }

    private var layoutDirectionForPreview: LayoutDirection {
        Locale.Language(identifier: previewLocale.identifier).characterDirection == .rightToLeft
            ? .rightToLeft
            : .leftToRight
    }

    var body: some View {
        NavigationStack {
            Group {
                if let prefs = preferences, draft != nil {
                    settingsContent(
                        preferences: prefs,
                        draftBinding: Binding(
                            get: { draft! },
                            set: { draft = $0 }
                        )
                    )
                } else if preferences != nil {
                    ProgressView(L10n.string("common.loading", locale: locale))
                        .task(id: preferences?.id) { loadDraftFromPreferences() }
                } else {
                    ProgressView(L10n.string("common.loading", locale: locale))
                }
            }
            .navigationTitle(Text(L10n.string("settings.title", locale: previewLocale)))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.done", locale: previewLocale)) {
                        commitAndDismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.primaryButton)
                    .accessibilityHint(Text(L10n.string("a11y.dismiss_settings_hint", locale: previewLocale)))
                }
            }
            .environment(\.locale, previewLocale)
            .environment(\.layoutDirection, layoutDirectionForPreview)
            .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
            .tint(themeManager.colors.secondaryText)
            .alert(
                L10n.string("settings.reset_setup.confirm_title", locale: previewLocale),
                isPresented: $showResetSetupConfirm
            ) {
                Button(L10n.string("settings.reset_setup.confirm_action", locale: previewLocale), role: .destructive) {
                    performResetSetup()
                }
                Button(L10n.string("common.cancel", locale: previewLocale), role: .cancel) {}
            } message: {
                Text(L10n.string("settings.reset_setup.confirm_message", locale: previewLocale))
            }
        }
        .background {
            if let sheetCoordinator {
                SettingsRevertRegistration(coordinator: sheetCoordinator, onRevert: revertIfNeeded)
            }
        }
    }

    private func loadDraftFromPreferences() {
        guard let prefs = preferences else { return }
        let snap = SettingsDraft(from: prefs)
        snapshot = snap
        draft = snap
        syncPickerState(from: snap)
        committed = false
    }

    private func syncPickerState(from draft: SettingsDraft) {
        selectedTheme = AppTheme(rawValue: draft.themeRaw) ?? .light
        selectedLanguage = AppLanguage.resolved(from: draft.preferredLanguageCode)
    }

    private func mutateDraft(_ draftBinding: Binding<SettingsDraft>, _ mutate: (inout SettingsDraft) -> Void) {
        var updated = draftBinding.wrappedValue
        mutate(&updated)
        draftBinding.wrappedValue = updated
    }

    private func revertIfNeeded() {
        guard !committed, let snap = snapshot else { return }
        try? store.updatePreferences { snap.write(to: &$0) }
        draft = snap
        syncPickerState(from: snap)
        themeManager.apply(theme: AppTheme(rawValue: snap.themeRaw) ?? .light)
    }

    private func commitAndDismiss() {
        guard let d = draft else { dismiss(); return }
        let validated = d.validatedForSave(locale: previewLocale)
        if let error = validated.error {
            commitValidationMessage = error
            return
        }
        committed = true
        do {
            try store.updatePreferences { validated.draft.write(to: &$0) }
            themeManager.apply(theme: AppTheme(rawValue: validated.draft.themeRaw) ?? .light)
            dismiss()
        } catch {
            committed = false
            commitValidationMessage = L10n.string("error.save_failed", locale: previewLocale)
        }
    }

    private func performResetSetup() {
        resetSetupError = nil
        do {
            try store.resetApp()
            committed = true
            dismiss()
        } catch {
            resetSetupError = L10n.string("error.save_failed", locale: previewLocale)
        }
    }

    @ViewBuilder
    private func settingsContent(preferences: AppPreferences, draftBinding: Binding<SettingsDraft>) -> some View {
        List {
            if let commitValidationMessage {
                Section {
                    Text(commitValidationMessage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeManager.colors.emergency)
                }
            }
            if let resetSetupError {
                Section {
                    Text(resetSetupError)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeManager.colors.emergency)
                }
            }

            Section {
                NavigationLink {
                    FavoriteContactsView()
                } label: {
                    Label {
                        Text(L10n.string("settings.link.favorites", locale: previewLocale))
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(themeManager.colors.primaryButton)
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(themeManager.colors.primaryText)
                }
                .accessibilityHint(Text(L10n.string("a11y.favorites_link_hint", locale: previewLocale)))
                .listRowBackground(themeManager.colors.groupedSurface)
            } header: {
                Text(L10n.string("settings.section.contacts", locale: previewLocale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themeManager.colors.secondaryText)
            }

            Section {
                Picker(L10n.string("settings.theme", locale: previewLocale), selection: $selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.localizedTitleKey).tag(theme)
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(themeManager.colors.primaryText)
                .tint(themeManager.colors.secondaryText)
                .listRowBackground(themeManager.colors.groupedSurface)
                .id("theme-picker-\(themeManager.currentTheme.rawValue)-\(selectedTheme.rawValue)")
                .onChange(of: selectedTheme) { _, newTheme in
                    mutateDraft(draftBinding) { $0.themeRaw = newTheme.rawValue }
                    themeManager.apply(theme: newTheme)
                }

                Picker(L10n.string("settings.language", locale: previewLocale), selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.nativeTitle).tag(lang)
                    }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(themeManager.colors.primaryText)
                .tint(themeManager.colors.secondaryText)
                .listRowBackground(themeManager.colors.groupedSurface)
                .id("language-picker-\(themeManager.currentTheme.rawValue)-\(selectedLanguage.rawValue)")
                .onChange(of: selectedLanguage) { _, newLanguage in
                    mutateDraft(draftBinding) { $0.preferredLanguageCode = newLanguage.rawValue }
                }

                textSizeSliderRow(draftBinding: draftBinding)
                    .listRowBackground(themeManager.colors.groupedSurface)

                Toggle(L10n.string("settings.voice", locale: previewLocale), isOn: Binding(
                    get: { draftBinding.wrappedValue.voicePromptsEnabled },
                    set: { enabled in mutateDraft(draftBinding) { $0.voicePromptsEnabled = enabled } }
                ))
                .font(.body.weight(.semibold))
                .tint(themeManager.colors.primaryButton)
                .listRowBackground(themeManager.colors.groupedSurface)
            } header: {
                Text(L10n.string("settings.section.accessibility", locale: previewLocale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themeManager.colors.secondaryText)
            }

            Section {
                Toggle(L10n.string("settings.sos.enable", locale: previewLocale), isOn: Binding(
                    get: { draftBinding.wrappedValue.sosEnabled },
                    set: { enabled in mutateDraft(draftBinding) { $0.sosEnabled = enabled } }
                ))
                .font(.body.weight(.semibold))
                .tint(themeManager.colors.primaryButton)
                .listRowBackground(themeManager.colors.groupedSurface)

                ThemedTextField(
                    prompt: L10n.string("settings.sos.number", locale: previewLocale),
                    text: Binding(
                        get: { draftBinding.wrappedValue.emergencyPhoneNumber },
                        set: { number in mutateDraft(draftBinding) { $0.emergencyPhoneNumber = number } }
                    ),
                    colors: themeManager.colors,
                    keyboardType: .phonePad
                )
                .font(.title3)
                .accessibilityLabel(Text(L10n.string("settings.sos.number", locale: previewLocale)))
                .listRowBackground(themeManager.colors.groupedSurface)
            } header: {
                Text(L10n.string("settings.section.sos", locale: previewLocale))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(themeManager.colors.secondaryText)
            } footer: {
                Text(L10n.string("settings.sos.footer", locale: previewLocale))
                    .font(.body)
                    .foregroundStyle(themeManager.colors.secondaryText)
            }

            Section {
                Button(L10n.string("settings.reset_setup", locale: previewLocale), role: .destructive) {
                    showResetSetupConfirm = true
                }
                .font(.body.weight(.semibold))
                .listRowBackground(themeManager.colors.groupedSurface)
            } footer: {
                Text(L10n.string("settings.reset_setup.footer", locale: previewLocale))
                    .font(.body)
                    .foregroundStyle(themeManager.colors.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.layoutDirection, layoutDirectionForPreview)
        .background(themeManager.colors.background)
        .scrollContentBackground(.hidden)
        .tint(themeManager.colors.secondaryText)
        .id(themeManager.currentTheme)
        .toolbarBackground(themeManager.colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func textSizeSliderBinding(_ draftBinding: Binding<SettingsDraft>) -> Binding<Double> {
        let maxIndex = Double(SettingsViewModel.dynamicTypeChoices.count)
        return Binding(
            get: {
                if draftBinding.wrappedValue.dynamicTypeSizeRaw == nil { return 0 }
                guard let size = SettingsViewModel.resolvedDynamicType(
                    storedRaw: draftBinding.wrappedValue.dynamicTypeSizeRaw
                ),
                let idx = SettingsViewModel.dynamicTypeChoices.firstIndex(of: size)
                else { return 0 }
                return Double(idx + 1)
            },
            set: { newValue in
                let i = min(max(Int(newValue.rounded()), 0), Int(maxIndex))
                mutateDraft(draftBinding) { draft in
                    if i == 0 {
                        draft.dynamicTypeSizeRaw = nil
                    } else {
                        let size = SettingsViewModel.dynamicTypeChoices[i - 1]
                        draft.dynamicTypeSizeRaw = String(describing: size)
                    }
                }
            }
        )
    }

    private func textSizeSliderCaption(for draft: SettingsDraft) -> String {
        if draft.dynamicTypeSizeRaw == nil {
            return L10n.string("settings.text_size.system", locale: previewLocale)
        }
        if let size = SettingsViewModel.resolvedDynamicType(storedRaw: draft.dynamicTypeSizeRaw) {
            return SettingsViewModel.localizedDynamicTypeLabel(size, locale: previewLocale)
        }
        return L10n.string("settings.text_size.system", locale: previewLocale)
    }

    @ViewBuilder
    private func textSizeSliderRow(draftBinding: Binding<SettingsDraft>) -> some View {
        let maxIndex = Double(SettingsViewModel.dynamicTypeChoices.count)
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("settings.text_size", locale: previewLocale))
                .font(.body.weight(.semibold))
            Text(textSizeSliderCaption(for: draftBinding.wrappedValue))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(themeManager.colors.secondaryText)

            HStack(alignment: .center, spacing: 14) {
                Text("A")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(themeManager.colors.secondaryText)
                    .accessibilityHidden(true)
                Slider(value: textSizeSliderBinding(draftBinding), in: 0...maxIndex, step: 1) {
                    Text(L10n.string("settings.text_size", locale: previewLocale))
                }
                .tint(themeManager.colors.primaryButton)
                .accessibilityValue(Text(textSizeSliderCaption(for: draftBinding.wrappedValue)))
                Text("A")
                    .font(.title.weight(.bold))
                    .foregroundStyle(themeManager.colors.primaryText)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    }
}

#Preview {
    SettingsView()
        .environment(\.appServices, AppServices())
        .environmentObject(ThemeManager())
        .environmentObject(AppStore.preview)
        .environment(\.locale, Locale(identifier: "en"))
}
