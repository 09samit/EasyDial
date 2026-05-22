//
//  SetupViewModel.swift
//  EasyDial
//
//  First-run setup: permissions, favorites import, labels, photos, theme, language.
//

import Combine
import Foundation

struct SetupDraftContact: Identifiable, Hashable {
    let id: UUID
    var cnContactIdentifier: String?
    var displayName: String
    var phoneNumber: String
    var photoData: Data?
}

@MainActor
final class SetupViewModel: ObservableObject {
    enum Step: Int {
        case permissions = 0
        case pickContacts = 1
        case relationships = 2
        case photos = 3
        case theme = 4
        case language = 5
        case finish = 6

        static let ordered: [Step] = [
            .permissions, .pickContacts, .relationships, .photos, .theme, .language, .finish,
        ]
    }

    @Published var step: Step = .permissions
    @Published var importedContacts: [ImportedContact] = []
    @Published var selectedImports: Set<String> = []
    @Published var drafts: [SetupDraftContact] = []
    @Published var loadError: String?
    @Published var permissionDenied = false

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    func rebuildDraftsFromSelection() {
        let cap = AppConfiguration.shared.maxFavoriteContactsDuringSetup
        let ordered = importedContacts.filter { selectedImports.contains($0.id) }.prefix(cap)
        let preserved = Dictionary(
            drafts.compactMap { draft -> (String, SetupDraftContact)? in
                guard let cn = draft.cnContactIdentifier else { return nil }
                return (cn, draft)
            },
            uniquingKeysWith: { first, _ in first }
        )
        drafts = ordered.map { src in
            if let existing = preserved[src.id] {
                var draft = existing
                draft.displayName = src.displayName
                if draft.photoData == nil { draft.photoData = src.thumbnailImageData }
                if CallService.sanitizePhone(draft.phoneNumber).isEmpty {
                    draft.phoneNumber = src.phoneNumbers.first ?? ""
                }
                return draft
            }
            return SetupDraftContact(
                id: UUID(),
                cnContactIdentifier: src.id,
                displayName: src.displayName,
                phoneNumber: src.phoneNumbers.first ?? "",
                photoData: src.thumbnailImageData
            )
        }
        selectedImports = Set(ordered.map(\.id))
    }

    func updatePhoto(for id: UUID, data: Data?) {
        guard let ix = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[ix].photoData = ImageDataOptimizer.thumbnailJPEG(from: data)
    }

    func updateDraft(id: UUID, phone: String) {
        guard let ix = drafts.firstIndex(where: { $0.id == id }) else { return }
        drafts[ix].phoneNumber = phone
    }

    func commitDrafts(store: AppStore, locale: Locale) throws {
        for (index, draft) in drafts.enumerated() {
            let contact = FavoriteContact(
                sortOrder: index,
                displayName: draft.displayName,
                relationshipLabel: FavoriteContact.hiddenRelationshipLabel,
                phoneNumber: CallService.sanitizePhone(draft.phoneNumber),
                cnContactIdentifier: draft.cnContactIdentifier
            )
            try store.insertFavorite(contact, photoData: draft.photoData)
        }
        try store.updatePreferences { $0.hasCompletedSetup = true }
    }
}
