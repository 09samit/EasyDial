//
//  ContactPicker.swift
//  EasyDial
//
//  Presents CNContactPickerViewController directly on the hosting UIViewController.
//  No intermediate SwiftUI sheet — zero blank-screen flash.
//

import Contacts
import ContactsUI
import SwiftUI

// MARK: - Result type

enum ContactPickerSelection {
    case contact(CNContact)
    case phone(contact: CNContact, number: String)
}

// MARK: - SwiftUI view modifier

extension View {
    /// Presents the system Contacts picker directly on the hosting UIViewController.
    /// No SwiftUI sheet is involved, so there is no blank intermediate modal.
    func contactPicker(
        isPresented: Binding<Bool>,
        excludedContactIdentifiers: Set<String> = [],
        excludedSanitizedPhones: Set<String> = [],
        onCancel: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onPick: @escaping (ContactPickerSelection) -> Void
    ) -> some View {
        self.background(
            _ContactPickerPresenter(
                isPresented: isPresented,
                excludedContactIdentifiers: excludedContactIdentifiers,
                excludedSanitizedPhones: excludedSanitizedPhones,
                onCancel: onCancel,
                onDuplicate: onDuplicate,
                onPick: onPick
            )
        )
    }
}

// MARK: - Zero-size UIViewControllerRepresentable

private struct _ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var excludedContactIdentifiers: Set<String>
    var excludedSanitizedPhones: Set<String>
    var onCancel: () -> Void
    var onDuplicate: () -> Void
    var onPick: (ContactPickerSelection) -> Void

    func makeUIViewController(context: Context) -> _ContactPickerHost {
        _ContactPickerHost()
    }

    func updateUIViewController(_ vc: _ContactPickerHost, context: Context) {
        context.coordinator.excludedContactIdentifiers = excludedContactIdentifiers
        context.coordinator.excludedSanitizedPhones = excludedSanitizedPhones
        context.coordinator.host = vc

        if isPresented && !vc.isPickerPresented {
            vc.isPickerPresented = true
            let picker = buildPicker(coordinator: context.coordinator)
            vc.present(picker, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isPresented: $isPresented,
            excludedContactIdentifiers: excludedContactIdentifiers,
            excludedSanitizedPhones: excludedSanitizedPhones,
            onCancel: onCancel,
            onDuplicate: onDuplicate,
            onPick: onPick
        )
    }

    private func buildPicker(coordinator: Coordinator) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = coordinator

        var predicates: [NSPredicate] = [
            NSPredicate(format: "phoneNumbers.@count > 0")
        ]
        if !excludedContactIdentifiers.isEmpty {
            predicates.append(
                NSPredicate(
                    format: "NOT (identifier IN %@)",
                    Array(excludedContactIdentifiers)
                )
            )
        }
        picker.predicateForEnablingContact =
            NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return picker
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, CNContactPickerDelegate {
        @Binding var isPresented: Bool
        var excludedContactIdentifiers: Set<String>
        var excludedSanitizedPhones: Set<String>
        private let onCancel: () -> Void
        private let onDuplicate: () -> Void
        private let onPick: (ContactPickerSelection) -> Void
        private var didDeliver = false
        weak var host: _ContactPickerHost?

        init(
            isPresented: Binding<Bool>,
            excludedContactIdentifiers: Set<String>,
            excludedSanitizedPhones: Set<String>,
            onCancel: @escaping () -> Void,
            onDuplicate: @escaping () -> Void,
            onPick: @escaping (ContactPickerSelection) -> Void
        ) {
            _isPresented = isPresented
            self.excludedContactIdentifiers = excludedContactIdentifiers
            self.excludedSanitizedPhones = excludedSanitizedPhones
            self.onCancel = onCancel
            self.onDuplicate = onDuplicate
            self.onPick = onPick
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish(picker) { self.onCancel() }
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if excludedContactIdentifiers.contains(contact.identifier) {
                finish(picker) { self.onDuplicate() }
            } else {
                finish(picker) { self.onPick(.contact(contact)) }
            }
        }

        func contactPicker(
            _ picker: CNContactPickerViewController,
            didSelect contactProperty: CNContactProperty
        ) {
            let contact = contactProperty.contact
            guard let phone = contactProperty.value as? CNPhoneNumber else { return }
            let raw = phone.stringValue
            let sanitized = CallService.sanitizePhone(raw)
            guard !sanitized.isEmpty else { return }

            if excludedContactIdentifiers.contains(contact.identifier)
                || excludedSanitizedPhones.contains(sanitized) {
                finish(picker) { self.onDuplicate() }
            } else {
                finish(picker) { self.onPick(.phone(contact: contact, number: raw)) }
            }
        }

        private func finish(_ picker: CNContactPickerViewController, action: @escaping () -> Void) {
            guard !didDeliver else { return }
            didDeliver = true
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                // Reset the host flag here — viewDidAppear on a zero-size
                // background VC is not reliable after UIKit modal dismissal.
                self.host?.isPickerPresented = false
                self.isPresented = false
                self.didDeliver = false
                DispatchQueue.main.async { action() }
            }
        }
    }
}

// MARK: - Transparent zero-size host

final class _ContactPickerHost: UIViewController {
    var isPickerPresented = false

    override func loadView() {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        view = v
    }
}
