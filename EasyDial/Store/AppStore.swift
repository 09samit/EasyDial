//
//  AppStore.swift
//  EasyDial
//
//  Single ObservableObject that owns all data reads and writes.
//  Views never import CoreData or touch NSManagedObject — they only see plain Swift structs.
//

import Foundation

// MARK: - AppStore

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var favorites: [FavoriteContact] = []
    @Published private(set) var preferences: AppPreferences?
    /// Cached photo data keyed by contact ID; refreshed after every favorites change.
    @Published private(set) var photoCache: [UUID: Data] = [:]
    @Published private(set) var isReady = false
    @Published private(set) var loadError: String?

    let photoStorage: any ContactPhotoStorage
    private let contactRepo: any FavoriteContactRepository
    private let prefsRepo: any AppPreferencesRepository

    init(
        contactRepo: any FavoriteContactRepository,
        prefsRepo: any AppPreferencesRepository,
        photoStorage: any ContactPhotoStorage
    ) {
        self.contactRepo = contactRepo
        self.prefsRepo = prefsRepo
        self.photoStorage = photoStorage
    }

    // MARK: - Bootstrap

    func bootstrap() {
        guard !isReady, loadError == nil else { return }
        do {
            try ensurePreferences()
            try normalizeLanguageCode()
            try reload()
            let validIDs = Set(favorites.map(\.id))
            photoStorage.cleanupOrphanedFiles(validIDs: validIDs)
            isReady = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Destroys persistent data and re-bootstraps from a clean state.
    func hardReset() {
        PersistenceController.resetStore()
        photoStorage.deleteAll()
        favorites = []
        preferences = nil
        photoCache = [:]
        loadError = nil
        isReady = false
        bootstrap()
    }

    // MARK: - Favorites Write

    func insertFavorite(_ contact: FavoriteContact, photoData: Data?) throws {
        if let data = photoData {
            // Best-effort: photo file failure is non-fatal; contact saves without photo.
            try? photoStorage.save(data, for: contact.id)
        }
        do {
            try contactRepo.insert(contact)
        } catch {
            // Roll back photo write to keep DB and filesystem consistent.
            if photoData != nil { photoStorage.delete(for: contact.id) }
            throw error
        }
        try reload()
    }

    func updateFavorite(_ contact: FavoriteContact, photoUpdate: PhotoUpdate = .unchanged) throws {
        switch photoUpdate {
        case .unchanged:
            break
        case .set(let data):
            try? photoStorage.save(data, for: contact.id)
        case .remove:
            photoStorage.delete(for: contact.id)
        }
        try contactRepo.update(contact)
        try reload()
    }

    func deleteFavorite(id: UUID) throws {
        try contactRepo.delete(id: id)
        photoStorage.delete(for: id)
        try reload()
    }

    func deleteAllFavorites() throws {
        try contactRepo.deleteAll()
        photoStorage.deleteAll()
        try reload()
    }

    func moveFavorites(from source: IndexSet, to destination: Int) throws {
        var ordered = favorites
        ordered.move(fromOffsets: source, toOffset: destination)
        for index in ordered.indices {
            ordered[index].sortOrder = index
        }
        try contactRepo.updateSortOrders(ordered)
        try reload()
    }

    // MARK: - Preferences Write

    func updatePreferences(_ block: (inout AppPreferences) -> Void) throws {
        guard var prefs = preferences else { return }
        block(&prefs)
        try prefsRepo.upsert(prefs)
        preferences = prefs
    }

    // MARK: - Reset

    func resetApp() throws {
        try deleteAllFavorites()
        try updatePreferences { prefs in
            prefs.hasCompletedSetup = false
            prefs.emergencyPhoneNumber = ""
        }
    }

    // MARK: - Private

    private func ensurePreferences() throws {
        guard (try prefsRepo.fetch()) == nil else { return }
        let defaults = AppPreferences(
            id: UUID(),
            hasCompletedSetup: false,
            themeRaw: AppTheme.light.rawValue,
            voicePromptsEnabled: true,
            sosEnabled: true,
            emergencyPhoneNumber: "",
            preferredLanguageCode: "en",
            dynamicTypeSizeRaw: nil
        )
        try prefsRepo.upsert(defaults)
    }

    private func normalizeLanguageCode() throws {
        guard var prefs = try prefsRepo.fetch() else { return }
        let supported = Set(AppLanguage.allCases.map(\.rawValue))
        guard !supported.contains(prefs.preferredLanguageCode) else { return }
        prefs.preferredLanguageCode = AppLanguage.english.rawValue
        try prefsRepo.upsert(prefs)
    }

    private func reload() throws {
        favorites = try contactRepo.fetchAllSorted()
        preferences = try prefsRepo.fetch()
        refreshPhotoCache()
    }

    private func refreshPhotoCache() {
        var cache: [UUID: Data] = [:]
        for contact in favorites {
            if let data = photoStorage.load(for: contact.id) {
                cache[contact.id] = data
            }
        }
        photoCache = cache
    }
}

// MARK: - Preview Convenience

extension AppStore {
    static var preview: AppStore {
        let store = AppStore(
            contactRepo: InMemoryFavoriteContactRepository.withSampleData(),
            prefsRepo: InMemoryAppPreferencesRepository.withDefaults(),
            photoStorage: InMemoryContactPhotoStorage()
        )
        store.bootstrap()
        return store
    }
}
