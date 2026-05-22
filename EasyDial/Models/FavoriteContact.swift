//
//  FavoriteContact.swift
//  EasyDial
//
//  Plain Swift struct for a favorite contact shown on the home grid.
//  No Core Data / SwiftData imports — views stay persistence-agnostic.
//

import Foundation

/// A value-type snapshot of a persisted favorite contact.
/// Photos are stored as files in the App Group container; this struct holds no image data.
struct FavoriteContact: Identifiable, Hashable {
    var id: UUID
    /// Stable ordering on the home screen (lower = appears first).
    var sortOrder: Int
    var displayName: String
    /// Legacy field kept for migration compatibility; not shown in the UI.
    var relationshipLabel: String
    /// Sanitized phone string suitable for `tel:` URLs (digits and leading +).
    var phoneNumber: String
    /// Optional link back to the system contact for future refresh flows.
    var cnContactIdentifier: String?
    var createdAt: Date

    /// Stored value used when the relationship field is hidden app-wide.
    static let hiddenRelationshipLabel = ""

    init(
        id: UUID = UUID(),
        sortOrder: Int,
        displayName: String,
        relationshipLabel: String,
        phoneNumber: String,
        cnContactIdentifier: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.displayName = displayName
        self.relationshipLabel = relationshipLabel
        self.phoneNumber = phoneNumber
        self.cnContactIdentifier = cnContactIdentifier
        self.createdAt = createdAt
    }
}
