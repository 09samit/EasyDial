//
//  AppStoreTests.swift
//  EasyDialTests
//
//  Tests for AppStore — bootstrap, CRUD, preferences, photo-rollback,
//  reorder, resetApp, and bootstrap guard.
//

import XCTest
@testable import EasyDial

@MainActor
final class AppStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore(
        contacts: [FavoriteContact] = [],
        prefs: AppPreferences? = nil
    ) -> AppStore {
        AppStore(
            contactRepo: InMemoryFavoriteContactRepository(contacts: contacts),
            prefsRepo: InMemoryAppPreferencesRepository(prefs: prefs),
            photoStorage: InMemoryContactPhotoStorage()
        )
    }

    private func bootstrappedStore(contacts: [FavoriteContact] = []) -> AppStore {
        let store = makeStore(contacts: contacts)
        store.bootstrap()
        return store
    }

    private func makeContact(sortOrder: Int = 0, id: UUID = UUID()) -> FavoriteContact {
        FavoriteContact(
            id: id,
            sortOrder: sortOrder,
            displayName: "Contact \(sortOrder)",
            relationshipLabel: "",
            phoneNumber: "555000\(sortOrder)"
        )
    }

    // MARK: - bootstrap

    func test_bootstrap_setsIsReady() {
        let store = bootstrappedStore()
        XCTAssertTrue(store.isReady)
    }

    func test_bootstrap_createsDefaultPreferences() {
        let store = bootstrappedStore()
        XCTAssertNotNil(store.preferences)
    }

    func test_bootstrap_defaultPreferences_hasCompletedSetupFalse() {
        let store = bootstrappedStore()
        XCTAssertFalse(store.preferences?.hasCompletedSetup ?? true)
    }

    func test_bootstrap_idempotent_calledTwice() {
        let store = makeStore()
        store.bootstrap()
        store.bootstrap() // Second call should be no-op
        XCTAssertTrue(store.isReady)
    }

    func test_bootstrap_normalizes_unsupportedLanguageCode() {
        let unsupportedPrefs = AppPreferences(preferredLanguageCode: "fr")
        let store = makeStore(prefs: unsupportedPrefs)
        store.bootstrap()
        XCTAssertEqual(store.preferences?.preferredLanguageCode, "en")
    }

    func test_bootstrap_keeps_supportedLanguageCode() {
        let prefs = AppPreferences(preferredLanguageCode: "ar")
        let store = makeStore(prefs: prefs)
        store.bootstrap()
        XCTAssertEqual(store.preferences?.preferredLanguageCode, "ar")
    }

    func test_bootstrap_loadsExistingContacts() {
        let store = bootstrappedStore(contacts: [makeContact(sortOrder: 0)])
        XCTAssertEqual(store.favorites.count, 1)
    }

    // MARK: - insertFavorite

    func test_insertFavorite_addsToFavorites() throws {
        let store = bootstrappedStore()
        let contact = makeContact(sortOrder: 0)
        try store.insertFavorite(contact, photoData: nil)
        XCTAssertEqual(store.favorites.count, 1)
    }

    func test_insertFavorite_withPhoto_storesInCache() throws {
        let store = bootstrappedStore()
        let id = UUID()
        let contact = makeContact(sortOrder: 0, id: id)
        let photoData = Data("photo".utf8)
        try store.insertFavorite(contact, photoData: photoData)
        XCTAssertNotNil(store.photoCache[id])
    }

    func test_insertFavorite_withoutPhoto_noCacheEntry() throws {
        let store = bootstrappedStore()
        let id = UUID()
        let contact = makeContact(sortOrder: 0, id: id)
        try store.insertFavorite(contact, photoData: nil)
        XCTAssertNil(store.photoCache[id])
    }

    // MARK: - updateFavorite

    func test_updateFavorite_unchanged_updatesContact() throws {
        let id = UUID()
        let store = bootstrappedStore(contacts: [makeContact(sortOrder: 0, id: id)])
        var updated = makeContact(sortOrder: 0, id: id)
        updated.displayName = "Updated"
        try store.updateFavorite(updated, photoUpdate: .unchanged)
        XCTAssertEqual(store.favorites.first?.displayName, "Updated")
    }

    func test_updateFavorite_setPhoto_addsToCache() throws {
        let id = UUID()
        let store = bootstrappedStore(contacts: [makeContact(sortOrder: 0, id: id)])
        let contact = makeContact(sortOrder: 0, id: id)
        try store.updateFavorite(contact, photoUpdate: .set(Data("photo".utf8)))
        XCTAssertNotNil(store.photoCache[id])
    }

    func test_updateFavorite_removePhoto_removesFromCache() throws {
        let id = UUID()
        let store = bootstrappedStore(contacts: [makeContact(sortOrder: 0, id: id)])
        let contact = makeContact(sortOrder: 0, id: id)
        try store.insertFavorite(contact, photoData: Data("photo".utf8))
        try store.updateFavorite(contact, photoUpdate: .remove)
        XCTAssertNil(store.photoCache[id])
    }

    // MARK: - deleteFavorite

    func test_deleteFavorite_removesByID() throws {
        let id = UUID()
        let store = bootstrappedStore(contacts: [makeContact(sortOrder: 0, id: id)])
        try store.deleteFavorite(id: id)
        XCTAssertTrue(store.favorites.isEmpty)
    }

    func test_deleteFavorite_removesFromPhotoCache() throws {
        let id = UUID()
        let store = bootstrappedStore()
        let contact = makeContact(sortOrder: 0, id: id)
        try store.insertFavorite(contact, photoData: Data("photo".utf8))
        try store.deleteFavorite(id: id)
        XCTAssertNil(store.photoCache[id])
    }

    // MARK: - deleteAllFavorites

    func test_deleteAllFavorites_clearsArray() throws {
        let store = bootstrappedStore(contacts: [
            makeContact(sortOrder: 0),
            makeContact(sortOrder: 1),
        ])
        try store.deleteAllFavorites()
        XCTAssertTrue(store.favorites.isEmpty)
    }

    // MARK: - moveFavorites

    func test_moveFavorites_reordersTwoItems() throws {
        let id0 = UUID()
        let id1 = UUID()
        let store = bootstrappedStore(contacts: [
            makeContact(sortOrder: 0, id: id0),
            makeContact(sortOrder: 1, id: id1),
        ])
        // Move first item to index 2 (swap)
        try store.moveFavorites(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(store.favorites[0].id, id1)
        XCTAssertEqual(store.favorites[1].id, id0)
    }

    func test_moveFavorites_updatesSequentialSortOrders() throws {
        let id0 = UUID()
        let id1 = UUID()
        let store = bootstrappedStore(contacts: [
            makeContact(sortOrder: 0, id: id0),
            makeContact(sortOrder: 1, id: id1),
        ])
        try store.moveFavorites(from: IndexSet(integer: 0), to: 2)
        let orders = store.favorites.map(\.sortOrder)
        XCTAssertEqual(orders, [0, 1])
    }

    // MARK: - updatePreferences

    func test_updatePreferences_changesValue() throws {
        let store = bootstrappedStore()
        try store.updatePreferences { $0.hasCompletedSetup = true }
        XCTAssertTrue(store.preferences?.hasCompletedSetup == true)
    }

    func test_updatePreferences_whenNilPrefs_noOp() throws {
        // Store with no pre-existing prefs but after bootstrap prefs exist; test when nil
        let store = AppStore(
            contactRepo: InMemoryFavoriteContactRepository(),
            prefsRepo: InMemoryAppPreferencesRepository(),
            photoStorage: InMemoryContactPhotoStorage()
        )
        // Don't bootstrap → preferences is nil
        XCTAssertNoThrow(try store.updatePreferences { $0.hasCompletedSetup = true })
    }

    // MARK: - resetApp

    func test_resetApp_clearsFavorites() throws {
        let store = bootstrappedStore(contacts: [makeContact(sortOrder: 0)])
        try store.resetApp()
        XCTAssertTrue(store.favorites.isEmpty)
    }

    func test_resetApp_setsHasCompletedSetup_false() throws {
        let store = bootstrappedStore()
        try store.updatePreferences { $0.hasCompletedSetup = true }
        try store.resetApp()
        XCTAssertFalse(store.preferences?.hasCompletedSetup ?? true)
    }

    func test_resetApp_clearsEmergencyPhone() throws {
        let store = bootstrappedStore()
        try store.updatePreferences { $0.emergencyPhoneNumber = "911" }
        try store.resetApp()
        XCTAssertEqual(store.preferences?.emergencyPhoneNumber, "")
    }

    // MARK: - photoCache consistency

    func test_photoCache_reflectsCurrentFavorites() throws {
        let id = UUID()
        let store = bootstrappedStore()
        try store.insertFavorite(makeContact(sortOrder: 0, id: id), photoData: Data("img".utf8))
        try store.deleteFavorite(id: id)
        XCTAssertNil(store.photoCache[id])
    }
}
