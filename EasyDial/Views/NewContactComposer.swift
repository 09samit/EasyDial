//
//  NewContactComposer.swift
//  EasyDial
//
//  Presents the system contact editor to add someone to the address book.
//

import Contacts
import ContactsUI
import SwiftUI

struct NewContactComposer: UIViewControllerRepresentable {
    var onComplete: (CNContact?) -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        let editor = CNContactViewController(forNewContact: contact)
        editor.delegate = context.coordinator
        editor.allowsEditing = true
        editor.allowsActions = false
        return UINavigationController(rootViewController: editor)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        private let onComplete: (CNContact?) -> Void

        init(onComplete: @escaping (CNContact?) -> Void) {
            self.onComplete = onComplete
        }

        func contactViewController(
            _ viewController: CNContactViewController,
            didCompleteWith contact: CNContact?
        ) {
            onComplete(contact)
        }
    }
}
