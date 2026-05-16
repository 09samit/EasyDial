//
//  PermissionManager.swift
//  EasyDial
//
//  Centralizes Contacts authorization for setup flows.
//

import Contacts
import Foundation
import UIKit

enum ContactsPermissionState {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
}

final class PermissionManager {
    private let store = CNContactStore()

    func contactsAuthorizationStatus() -> ContactsPermissionState {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .limited: return .limited
        @unknown default: return .denied
        }
    }

    /// Whether contact reads are allowed (full, or limited on iOS 18+).
    func canReadContacts() -> Bool {
        switch contactsAuthorizationStatus() {
        case .authorized, .limited: return true
        case .notDetermined, .denied, .restricted: return false
        }
    }

    func requestContactsAccess() async -> Bool {
        let status = contactsAuthorizationStatus()
        if status == .authorized || status == .limited {
            return true
        }
        return await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
