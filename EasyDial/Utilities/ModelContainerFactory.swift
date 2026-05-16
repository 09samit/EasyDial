//
//  ModelContainerFactory.swift
//  EasyDial
//
//  Creates the SwiftData store with a single automatic recovery attempt before surfacing UI.
//

import Foundation
import SwiftData

enum ModelContainerFactory {
    private static let recoveryAttemptedKey = "EasyDial.swiftDataRecoveryAttempted"

    static func makePersistentContainer() throws -> ModelContainer {
        let schema = Schema([FavoriteContact.self, AppPreferences.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            let defaults = UserDefaults.standard
            if !defaults.bool(forKey: recoveryAttemptedKey) {
                defaults.set(true, forKey: recoveryAttemptedKey)
                destroyPersistentStoreFiles()
                return try ModelContainer(for: schema, configurations: config)
            }
            throw error
        }
    }

    /// Deletes default SwiftData store files so the next launch can recreate a clean container.
    static func destroyPersistentStoreFiles() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let names = ["default.store", "default.store-shm", "default.store-wal"]
        for name in names {
            let url = appSupport.appendingPathComponent(name)
            try? fm.removeItem(at: url)
        }
    }

    static func clearRecoveryAttemptFlag() {
        UserDefaults.standard.removeObject(forKey: recoveryAttemptedKey)
    }
}
