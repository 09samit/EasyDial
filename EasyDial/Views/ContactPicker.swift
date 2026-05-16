//
//  ContactPicker.swift
//  EasyDial
//
//  Presents the system Contacts picker modally (required by ContactsUI).
//

import Contacts
import ContactsUI
import SwiftUI

/// Result from the system contact picker.
enum ContactPickerSelection {
    case contact(CNContact)
    case phone(contact: CNContact, number: String)
}

/// Host view controller — `CNContactPickerViewController` must be presented modally, not used as the representable root.
final class ContactPickerHostViewController: UIViewController {
    var excludedContactIdentifiers: Set<String> = []
    weak var coordinator: ContactPicker.Coordinator?
    private var didPresentPicker = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !didPresentPicker else { return }
        didPresentPicker = true
        presentConfiguredPicker()
    }

    private func presentConfiguredPicker() {
        let picker = CNContactPickerViewController()
        picker.delegate = coordinator

        // Do not set `displayedPropertyKeys` — that mode forces users into contact detail
        // to pick a phone line. Leaving it unset lets a row tap select the contact and dismiss.

        var enablingPredicates: [NSPredicate] = [
            NSPredicate(format: "phoneNumbers.@count > 0")
        ]
        if !excludedContactIdentifiers.isEmpty {
            enablingPredicates.append(
                NSPredicate(
                    format: "NOT (identifier IN %@)",
                    Array(excludedContactIdentifiers)
                )
            )
        }
        picker.predicateForEnablingContact = NSCompoundPredicate(andPredicateWithSubpredicates: enablingPredicates)

        present(picker, animated: true)
    }
}

struct ContactPicker: UIViewControllerRepresentable {
    var excludedContactIdentifiers: Set<String> = []
    var excludedSanitizedPhones: Set<String> = []
    var onCancel: () -> Void
    var onDuplicate: () -> Void
    var onPick: (ContactPickerSelection) -> Void

    func makeUIViewController(context: Context) -> ContactPickerHostViewController {
        let host = ContactPickerHostViewController()
        host.coordinator = context.coordinator
        host.excludedContactIdentifiers = excludedContactIdentifiers
        return host
    }

    func updateUIViewController(_ uiViewController: ContactPickerHostViewController, context: Context) {
        uiViewController.excludedContactIdentifiers = excludedContactIdentifiers
        context.coordinator.excludedContactIdentifiers = excludedContactIdentifiers
        context.coordinator.excludedSanitizedPhones = excludedSanitizedPhones
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            excludedContactIdentifiers: excludedContactIdentifiers,
            excludedSanitizedPhones: excludedSanitizedPhones,
            onCancel: onCancel,
            onDuplicate: onDuplicate,
            onPick: onPick
        )
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var excludedContactIdentifiers: Set<String>
        var excludedSanitizedPhones: Set<String>
        private let onCancel: () -> Void
        private let onDuplicate: () -> Void
        private let onPick: (ContactPickerSelection) -> Void
        private var didDeliverSelection = false

        init(
            excludedContactIdentifiers: Set<String>,
            excludedSanitizedPhones: Set<String>,
            onCancel: @escaping () -> Void,
            onDuplicate: @escaping () -> Void,
            onPick: @escaping (ContactPickerSelection) -> Void
        ) {
            self.excludedContactIdentifiers = excludedContactIdentifiers
            self.excludedSanitizedPhones = excludedSanitizedPhones
            self.onCancel = onCancel
            self.onDuplicate = onDuplicate
            self.onPick = onPick
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.deliverOnMain { self.onCancel() }
            }
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if excludedContactIdentifiers.contains(contact.identifier) {
                deliverDuplicate(from: picker)
                return
            }
            deliverSelection(.contact(contact), from: picker)
        }

        func contactPicker(
            _ picker: CNContactPickerViewController,
            didSelect contactProperty: CNContactProperty
        ) {
            let contact = contactProperty.contact
            if excludedContactIdentifiers.contains(contact.identifier) {
                deliverDuplicate(from: picker)
                return
            }

            guard let phone = contactProperty.value as? CNPhoneNumber else { return }
            let raw = phone.stringValue
            let sanitized = CallService.sanitizePhone(raw)
            guard !sanitized.isEmpty else { return }

            if excludedSanitizedPhones.contains(sanitized) {
                deliverDuplicate(from: picker)
                return
            }

            deliverSelection(.phone(contact: contact, number: raw), from: picker)
        }

        private func deliverDuplicate(from picker: CNContactPickerViewController) {
            guard !didDeliverSelection else { return }
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.deliverOnMain { self.onDuplicate() }
            }
        }

        private func deliverSelection(_ selection: ContactPickerSelection, from picker: CNContactPickerViewController) {
            guard !didDeliverSelection else { return }
            didDeliverSelection = true
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.deliverOnMain {
                    self.onPick(selection)
                }
            }
        }

        private func deliverOnMain(_ action: @escaping () -> Void) {
            if Thread.isMainThread {
                action()
            } else {
                DispatchQueue.main.async(execute: action)
            }
        }
    }
}
