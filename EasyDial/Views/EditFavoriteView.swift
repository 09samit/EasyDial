//
//  EditFavoriteView.swift
//  EasyDial
//
//  Update an existing favorite's name, phone, and photo.
//

import PhotosUI
import SwiftUI

struct EditFavoriteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: AppStore

    let contact: FavoriteContact

    @StateObject private var viewModel = ContactViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var validationError: String?
    @State private var saveError: String?

    var body: some View {
        Form {
            if let validationError {
                Text(validationError)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.emergency)
            }
            if let saveError {
                Text(saveError)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(themeManager.colors.emergency)
            }

            Section {
                ThemedTextField(
                    prompt: L10n.string("editor.name", locale: locale),
                    text: $viewModel.displayName,
                    colors: themeManager.colors
                )
                .font(.title3)

                ThemedTextField(
                    prompt: L10n.string("editor.phone", locale: locale),
                    text: $viewModel.phoneNumber,
                    colors: themeManager.colors,
                    keyboardType: .phonePad
                )
                .font(.title3)
            }

            Section {
                if let data = viewModel.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Label(L10n.string("setup.photos.change", locale: locale), systemImage: "photo")
                }

                if viewModel.photoData != nil {
                    Button(L10n.string("setup.photos.remove", locale: locale), role: .destructive) {
                        photoItem = nil
                        viewModel.photoData = nil
                        viewModel.photoRemoved = true
                        viewModel.photoChanged = false
                    }
                }
            }
        }
        .navigationTitle(Text(L10n.string("editor.title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string("common.cancel", locale: locale)) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.string("common.save", locale: locale)) { save() }
                    .font(.body.weight(.bold))
            }
        }
        .onAppear {
            viewModel.reset(from: contact, photoStorage: store.photoStorage)
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.photoData = ImageDataOptimizer.thumbnailJPEG(from: data)
                        viewModel.photoChanged = true
                        viewModel.photoRemoved = false
                    }
                }
            }
        }
    }

    private func save() {
        validationError = nil
        saveError = nil
        if let message = viewModel.validate(locale: locale) {
            validationError = message
            return
        }
        var updated = contact
        updated.displayName = viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.phoneNumber = CallService.sanitizePhone(viewModel.phoneNumber)

        let photoUpdate: PhotoUpdate
        if viewModel.photoRemoved {
            photoUpdate = .remove
        } else if viewModel.photoChanged, let data = viewModel.photoData {
            photoUpdate = .set(data)
        } else {
            photoUpdate = .unchanged
        }

        do {
            try store.updateFavorite(updated, photoUpdate: photoUpdate)
            dismiss()
        } catch {
            saveError = L10n.string("error.save_failed", locale: locale)
        }
    }
}
