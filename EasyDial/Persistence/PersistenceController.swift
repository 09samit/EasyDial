//
//  PersistenceController.swift
//  EasyDial
//
//  Core Data stack: programmatic model, App Group container for widget access.
//

import CoreData
import Foundation

// MARK: - NSManagedObject Subclasses

@objc(FavoriteContactEntity)
final class FavoriteContactEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var sortOrder: Int32
    @NSManaged var displayName: String
    @NSManaged var relationshipLabel: String
    @NSManaged var phoneNumber: String
    @NSManaged var cnContactIdentifier: String?
    @NSManaged var createdAt: Date
}

@objc(AppPreferencesEntity)
final class AppPreferencesEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var hasCompletedSetup: Bool
    @NSManaged var themeRaw: String
    @NSManaged var voicePromptsEnabled: Bool
    @NSManaged var sosEnabled: Bool
    @NSManaged var emergencyPhoneNumber: String
    @NSManaged var preferredLanguageCode: String
    @NSManaged var dynamicTypeSizeRaw: String?
}

// MARK: - Fetch Request Helpers

extension FavoriteContactEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<FavoriteContactEntity> {
        NSFetchRequest<FavoriteContactEntity>(entityName: "FavoriteContactEntity")
    }
}

extension AppPreferencesEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<AppPreferencesEntity> {
        NSFetchRequest<AppPreferencesEntity>(entityName: "AppPreferencesEntity")
    }
}

// MARK: - Model Mappers

extension FavoriteContact {
    init(entity: FavoriteContactEntity) {
        self.id = entity.id
        self.sortOrder = Int(entity.sortOrder)
        self.displayName = entity.displayName
        self.relationshipLabel = entity.relationshipLabel
        self.phoneNumber = entity.phoneNumber
        self.cnContactIdentifier = entity.cnContactIdentifier
        self.createdAt = entity.createdAt
    }

    func apply(to entity: FavoriteContactEntity) {
        entity.id = id
        entity.sortOrder = Int32(sortOrder)
        entity.displayName = displayName
        entity.relationshipLabel = relationshipLabel
        entity.phoneNumber = phoneNumber
        entity.cnContactIdentifier = cnContactIdentifier
        entity.createdAt = createdAt
    }
}

extension AppPreferences {
    init(entity: AppPreferencesEntity) {
        self.id = entity.id
        self.hasCompletedSetup = entity.hasCompletedSetup
        self.themeRaw = entity.themeRaw
        self.voicePromptsEnabled = entity.voicePromptsEnabled
        self.sosEnabled = entity.sosEnabled
        self.emergencyPhoneNumber = entity.emergencyPhoneNumber
        self.preferredLanguageCode = entity.preferredLanguageCode
        self.dynamicTypeSizeRaw = entity.dynamicTypeSizeRaw
    }

    func apply(to entity: AppPreferencesEntity) {
        entity.id = id
        entity.hasCompletedSetup = hasCompletedSetup
        entity.themeRaw = themeRaw
        entity.voicePromptsEnabled = voicePromptsEnabled
        entity.sosEnabled = sosEnabled
        entity.emergencyPhoneNumber = emergencyPhoneNumber
        entity.preferredLanguageCode = preferredLanguageCode
        entity.dynamicTypeSizeRaw = dynamicTypeSizeRaw
    }
}

// MARK: - PersistenceController

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "EasyDial",
            managedObjectModel: PersistenceController.makeModel()
        )

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let groupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.hexa.easydial")
            if let groupURL {
                let storeURL = groupURL.appendingPathComponent("EasyDial.sqlite")
                let desc = NSPersistentStoreDescription(url: storeURL)
                desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                container.persistentStoreDescriptions = [desc]
            } else {
                // App Group entitlement missing: fall back to Application Support (no widget access)
                container.persistentStoreDescriptions.first?
                    .setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            }
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if loadError != nil, !inMemory {
            // One silent recovery attempt: destroy and reload
            PersistenceController.destroyStore()
            container.loadPersistentStores { _, _ in }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Removes persistent store from coordinator, deletes backing SQLite files,
    /// then re-adds a fresh empty store. Safe to call before re-bootstrapping AppStore.
    static func resetStore() {
        let coordinator = shared.container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            let url = store.url
            try? coordinator.remove(store)
            if let url {
                let base = url.deletingLastPathComponent()
                let name = url.deletingPathExtension().lastPathComponent
                for suffix in ["", "-shm", "-wal"] {
                    try? FileManager.default.removeItem(
                        at: base.appendingPathComponent(name + ".sqlite" + suffix)
                    )
                }
            }
        }
        // Re-add store so the container is in a usable state
        let desc = shared.container.persistentStoreDescriptions.first
        let storeURL = desc?.url
        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentHistoryTrackingKey: true
        ]
        try? coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: storeURL != nil ? options : nil
        )
        shared.container.viewContext.reset()
    }

    /// Deletes SQLite files from both the App Group and Application Support directories.
    static func destroyStore() {
        let fm = FileManager.default
        let suffixes = [".sqlite", ".sqlite-shm", ".sqlite-wal"]
        let dirs: [URL?] = [
            fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.hexa.easydial"),
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ]
        for dir in dirs.compactMap({ $0 }) {
            for suffix in suffixes {
                try? fm.removeItem(at: dir.appendingPathComponent("EasyDial\(suffix)"))
            }
        }
    }

    // MARK: - Programmatic Managed Object Model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let contactEntity = NSEntityDescription()
        contactEntity.name = "FavoriteContactEntity"
        contactEntity.managedObjectClassName = NSStringFromClass(FavoriteContactEntity.self)
        contactEntity.properties = [
            attr("id",                   .UUIDAttributeType),
            attr("sortOrder",            .integer32AttributeType),
            attr("displayName",          .stringAttributeType),
            attr("relationshipLabel",    .stringAttributeType),
            attr("phoneNumber",          .stringAttributeType),
            attr("cnContactIdentifier",  .stringAttributeType, optional: true),
            attr("createdAt",            .dateAttributeType),
        ]

        let prefsEntity = NSEntityDescription()
        prefsEntity.name = "AppPreferencesEntity"
        prefsEntity.managedObjectClassName = NSStringFromClass(AppPreferencesEntity.self)
        prefsEntity.properties = [
            attr("id",                       .UUIDAttributeType),
            attr("hasCompletedSetup",        .booleanAttributeType),
            attr("themeRaw",                 .stringAttributeType),
            attr("voicePromptsEnabled",      .booleanAttributeType),
            attr("sosEnabled",               .booleanAttributeType),
            attr("emergencyPhoneNumber",     .stringAttributeType),
            attr("preferredLanguageCode",    .stringAttributeType),
            attr("dynamicTypeSizeRaw",       .stringAttributeType, optional: true),
        ]

        model.entities = [contactEntity, prefsEntity]
        return model
    }

    private static func attr(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        return a
    }
}
