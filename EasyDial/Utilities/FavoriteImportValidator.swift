//
//  FavoriteImportValidator.swift
//  EasyDial
//
//  Validates favorite imports against limits and existing rows.
//

import Foundation

enum FavoriteImportIssue: Equatable {
    case atFavoriteLimit
    case duplicateContact
    case duplicatePhone
    case noDialablePhone
    case saveFailed
}

struct FavoriteImportValidator {
    let excludedContactIDs: Set<String>
    let excludedPhones: Set<String>
    let favoriteCount: Int
    let limit: Int

    init(favorites: [FavoriteContact], limit: Int) {
        excludedContactIDs = Set(favorites.compactMap(\.cnContactIdentifier))
        excludedPhones = Set(favorites.map(\.phoneNumber).filter { !$0.isEmpty })
        favoriteCount = favorites.count
        self.limit = max(1, limit)
    }

    var canAdd: Bool { favoriteCount < limit }

    func issue(contactID: String, sanitizedPhone: String) -> FavoriteImportIssue? {
        guard canAdd else { return .atFavoriteLimit }
        if excludedContactIDs.contains(contactID) { return .duplicateContact }
        if !sanitizedPhone.isEmpty, excludedPhones.contains(sanitizedPhone) { return .duplicatePhone }
        return nil
    }
}
