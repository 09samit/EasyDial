//
//  FavoriteContact.swift
//  EasyDial
//
//  SwiftData model for a favorite contact shown on the home grid.
//

import Foundation
import SwiftData

/// A persisted favorite contact row. Stores denormalized fields so calling works without Contacts access at tap time.
@Model
final class FavoriteContact {
    var id: UUID
    /// Stable ordering on the home screen (lower appears first).
    var sortOrder: Int
    var displayName: String
    /// Legacy field kept for SwiftData compatibility; not shown in the UI.
    var relationshipLabel: String

    /// Stored value for favorites when the relationship field is hidden app-wide.
    static let hiddenRelationshipLabel = ""
    /// Sanitized phone string suitable for `tel:` URLs (digits and leading +).
    var phoneNumber: String
    /// Optional square photo bytes copied from Contacts or Photos.
    @Attribute(.externalStorage)
    var photoData: Data?
    /// Optional link back to the system contact for future refresh flows.
    var cnContactIdentifier: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sortOrder: Int,
        displayName: String,
        relationshipLabel: String,
        phoneNumber: String,
        photoData: Data? = nil,
        cnContactIdentifier: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.displayName = displayName
        self.relationshipLabel = relationshipLabel
        self.phoneNumber = phoneNumber
        self.photoData = photoData
        self.cnContactIdentifier = cnContactIdentifier
        self.createdAt = createdAt
    }
}
