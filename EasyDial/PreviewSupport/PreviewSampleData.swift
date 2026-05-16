//
//  PreviewSampleData.swift
//  EasyDial
//
//  In-memory SwiftData + sample favorites for SwiftUI previews (not shipped to users).
//

import SwiftData
import SwiftUI

enum PreviewSampleData {
    static let container: ModelContainer = {
        let schema = Schema([FavoriteContact.self, AppPreferences.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let prefs = AppPreferences(
            hasCompletedSetup: true,
            preferredLanguageCode: "en"
        )
        context.insert(prefs)
        let c1 = FavoriteContact(
            sortOrder: 0,
            displayName: "Priya Sharma",
            relationshipLabel: FavoriteContact.hiddenRelationshipLabel,
            phoneNumber: "5555550100"
        )
        let c2 = FavoriteContact(
            sortOrder: 1,
            displayName: "Dr. Patel",
            relationshipLabel: FavoriteContact.hiddenRelationshipLabel,
            phoneNumber: "5555550200"
        )
        context.insert(c1)
        context.insert(c2)
        try? context.save()
        return container
    }()
}
