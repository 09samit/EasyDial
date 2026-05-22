//
//  Repositories.swift
//  EasyDial
//
//  Repository protocols and implementations (Core Data + in-memory) for favorites and preferences.
//

import CoreData
import Foundation

// MARK: - Protocols

protocol FavoriteContactRepository {
    func fetchAllSorted() throws -> [FavoriteContact]
    func insert(_ contact: FavoriteContact) throws
    func update(_ contact: FavoriteContact) throws
    func delete(id: UUID) throws
    func deleteAll() throws
    func updateSortOrders(_ contacts: [FavoriteContact]) throws
}

protocol AppPreferencesRepository {
    func fetch() throws -> AppPreferences?
    func upsert(_ prefs: AppPreferences) throws
}

// MARK: - Repository Error

enum RepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? { "Record not found." }
}

// MARK: - Core Data: FavoriteContact

final class CoreDataFavoriteContactRepository: FavoriteContactRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAllSorted() throws -> [FavoriteContact] {
        let request = FavoriteContactEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        return try context.fetch(request).map(FavoriteContact.init(entity:))
    }

    func insert(_ contact: FavoriteContact) throws {
        let entity = FavoriteContactEntity(context: context)
        contact.apply(to: entity)
        try context.save()
    }

    func update(_ contact: FavoriteContact) throws {
        let entity = try findEntity(id: contact.id)
        contact.apply(to: entity)
        try context.save()
    }

    func delete(id: UUID) throws {
        let entity = try findEntity(id: id)
        context.delete(entity)
        try context.save()
    }

    func deleteAll() throws {
        let request = FavoriteContactEntity.fetchRequest()
        let entities = try context.fetch(request)
        entities.forEach { context.delete($0) }
        try context.save()
    }

    func updateSortOrders(_ contacts: [FavoriteContact]) throws {
        let request = FavoriteContactEntity.fetchRequest()
        let entities = try context.fetch(request)
        let entityMap = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        for contact in contacts {
            entityMap[contact.id]?.sortOrder = Int32(contact.sortOrder)
        }
        try context.save()
    }

    private func findEntity(id: UUID) throws -> FavoriteContactEntity {
        let request = FavoriteContactEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        return entity
    }
}

// MARK: - Core Data: AppPreferences

final class CoreDataAppPreferencesRepository: AppPreferencesRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() throws -> AppPreferences? {
        let request = AppPreferencesEntity.fetchRequest()
        request.fetchLimit = 1
        return try context.fetch(request).first.map(AppPreferences.init(entity:))
    }

    func upsert(_ prefs: AppPreferences) throws {
        let request = AppPreferencesEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", prefs.id as CVarArg)
        request.fetchLimit = 1
        let entity: AppPreferencesEntity
        if let existing = try context.fetch(request).first {
            entity = existing
        } else {
            entity = AppPreferencesEntity(context: context)
        }
        prefs.apply(to: entity)
        try context.save()
    }
}

// MARK: - In-Memory: FavoriteContact (Previews + Tests)

final class InMemoryFavoriteContactRepository: FavoriteContactRepository {
    var contacts: [FavoriteContact]

    init(contacts: [FavoriteContact] = []) {
        self.contacts = contacts
    }

    static func withSampleData() -> InMemoryFavoriteContactRepository {
        InMemoryFavoriteContactRepository(contacts: [
            FavoriteContact(
                id: UUID(), sortOrder: 0, displayName: "Priya Sharma",
                relationshipLabel: "", phoneNumber: "5555550100",
                cnContactIdentifier: nil, createdAt: Date()
            ),
            FavoriteContact(
                id: UUID(), sortOrder: 1, displayName: "Dr. Patel",
                relationshipLabel: "", phoneNumber: "5555550200",
                cnContactIdentifier: nil, createdAt: Date()
            ),
        ])
    }

    func fetchAllSorted() throws -> [FavoriteContact] {
        contacts.sorted { $0.sortOrder < $1.sortOrder }
    }

    func insert(_ contact: FavoriteContact) throws {
        contacts.append(contact)
    }

    func update(_ contact: FavoriteContact) throws {
        guard let ix = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[ix] = contact
    }

    func delete(id: UUID) throws {
        contacts.removeAll { $0.id == id }
    }

    func deleteAll() throws {
        contacts.removeAll()
    }

    func updateSortOrders(_ updated: [FavoriteContact]) throws {
        for u in updated {
            if let ix = contacts.firstIndex(where: { $0.id == u.id }) {
                contacts[ix].sortOrder = u.sortOrder
            }
        }
    }
}

// MARK: - In-Memory: AppPreferences (Previews + Tests)

final class InMemoryAppPreferencesRepository: AppPreferencesRepository {
    var prefs: AppPreferences?

    init(prefs: AppPreferences? = nil) {
        self.prefs = prefs
    }

    static func withDefaults() -> InMemoryAppPreferencesRepository {
        InMemoryAppPreferencesRepository(prefs: AppPreferences(
            id: UUID(),
            hasCompletedSetup: true,
            themeRaw: AppTheme.light.rawValue,
            voicePromptsEnabled: true,
            sosEnabled: true,
            emergencyPhoneNumber: "",
            preferredLanguageCode: "en",
            dynamicTypeSizeRaw: nil
        ))
    }

    func fetch() throws -> AppPreferences? { prefs }
    func upsert(_ newPrefs: AppPreferences) throws { prefs = newPrefs }
}
