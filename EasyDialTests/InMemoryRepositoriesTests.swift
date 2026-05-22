//
//  InMemoryRepositoriesTests.swift
//  EasyDialTests
//
//  Tests for InMemoryFavoriteContactRepository and InMemoryAppPreferencesRepository.
//  These are the same implementations used in production previews, so their correctness
//  directly validates preview data integrity and test harness reliability.
//

import XCTest
@testable import EasyDial

// MARK: - FavoriteContact Repository

final class InMemoryFavoriteContactRepositoryTests: XCTestCase {

    private func makeContact(sortOrder: Int = 0, id: UUID = UUID()) -> FavoriteContact {
        FavoriteContact(
            id: id,
            sortOrder: sortOrder,
            displayName: "Test \(sortOrder)",
            relationshipLabel: "",
            phoneNumber: "555000\(sortOrder)"
        )
    }

    // MARK: - fetchAllSorted

    func test_fetchAllSorted_empty() throws {
        let repo = InMemoryFavoriteContactRepository()
        XCTAssertTrue(try repo.fetchAllSorted().isEmpty)
    }

    func test_fetchAllSorted_returnsSortedBySortOrder() throws {
        let repo = InMemoryFavoriteContactRepository(contacts: [
            makeContact(sortOrder: 2),
            makeContact(sortOrder: 0),
            makeContact(sortOrder: 1),
        ])
        let sorted = try repo.fetchAllSorted()
        XCTAssertEqual(sorted.map(\.sortOrder), [0, 1, 2])
    }

    // MARK: - insert

    func test_insert_addsContact() throws {
        let repo = InMemoryFavoriteContactRepository()
        let contact = makeContact(sortOrder: 0)
        try repo.insert(contact)
        let all = try repo.fetchAllSorted()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, contact.id)
    }

    func test_insert_multipleContacts() throws {
        let repo = InMemoryFavoriteContactRepository()
        try repo.insert(makeContact(sortOrder: 1))
        try repo.insert(makeContact(sortOrder: 0))
        let all = try repo.fetchAllSorted()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.sortOrder, 0)
    }

    // MARK: - update

    func test_update_changesDisplayName() throws {
        let id = UUID()
        let repo = InMemoryFavoriteContactRepository(contacts: [makeContact(sortOrder: 0, id: id)])
        var updated = makeContact(sortOrder: 0, id: id)
        updated.displayName = "Updated Name"
        try repo.update(updated)
        let result = try repo.fetchAllSorted()
        XCTAssertEqual(result.first?.displayName, "Updated Name")
    }

    func test_update_nonExistentID_noError() throws {
        let repo = InMemoryFavoriteContactRepository()
        let contact = makeContact(sortOrder: 0)
        // Should not throw for missing ID in InMemory implementation
        XCTAssertNoThrow(try repo.update(contact))
    }

    // MARK: - delete

    func test_delete_removesContact() throws {
        let id = UUID()
        let repo = InMemoryFavoriteContactRepository(contacts: [makeContact(sortOrder: 0, id: id)])
        try repo.delete(id: id)
        XCTAssertTrue(try repo.fetchAllSorted().isEmpty)
    }

    func test_delete_nonExistentID_noError() throws {
        let repo = InMemoryFavoriteContactRepository()
        XCTAssertNoThrow(try repo.delete(id: UUID()))
    }

    func test_delete_onlyRemovesTargetContact() throws {
        let id1 = UUID()
        let id2 = UUID()
        let repo = InMemoryFavoriteContactRepository(contacts: [
            makeContact(sortOrder: 0, id: id1),
            makeContact(sortOrder: 1, id: id2),
        ])
        try repo.delete(id: id1)
        let remaining = try repo.fetchAllSorted()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, id2)
    }

    // MARK: - deleteAll

    func test_deleteAll_clearsEverything() throws {
        let repo = InMemoryFavoriteContactRepository(contacts: [
            makeContact(sortOrder: 0), makeContact(sortOrder: 1),
        ])
        try repo.deleteAll()
        XCTAssertTrue(try repo.fetchAllSorted().isEmpty)
    }

    func test_deleteAll_emptyRepo_noError() throws {
        let repo = InMemoryFavoriteContactRepository()
        XCTAssertNoThrow(try repo.deleteAll())
    }

    // MARK: - updateSortOrders

    func test_updateSortOrders_appliesNewOrders() throws {
        let id1 = UUID()
        let id2 = UUID()
        let repo = InMemoryFavoriteContactRepository(contacts: [
            makeContact(sortOrder: 0, id: id1),
            makeContact(sortOrder: 1, id: id2),
        ])
        let reordered = [
            FavoriteContact(id: id1, sortOrder: 5, displayName: "", relationshipLabel: "", phoneNumber: ""),
            FavoriteContact(id: id2, sortOrder: 3, displayName: "", relationshipLabel: "", phoneNumber: ""),
        ]
        try repo.updateSortOrders(reordered)
        let results = try repo.fetchAllSorted()
        let orders = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0.sortOrder) })
        XCTAssertEqual(orders[id1], 5)
        XCTAssertEqual(orders[id2], 3)
    }

    func test_updateSortOrders_unknownID_ignored() throws {
        let id = UUID()
        let repo = InMemoryFavoriteContactRepository(contacts: [makeContact(sortOrder: 0, id: id)])
        let ghost = FavoriteContact(id: UUID(), sortOrder: 99, displayName: "", relationshipLabel: "", phoneNumber: "")
        XCTAssertNoThrow(try repo.updateSortOrders([ghost]))
        let result = try repo.fetchAllSorted()
        XCTAssertEqual(result.first?.sortOrder, 0) // Original unchanged
    }

    // MARK: - withSampleData

    func test_withSampleData_returnsTwoContacts() throws {
        let repo = InMemoryFavoriteContactRepository.withSampleData()
        let all = try repo.fetchAllSorted()
        XCTAssertEqual(all.count, 2)
    }

    func test_withSampleData_sortedOrder() throws {
        let repo = InMemoryFavoriteContactRepository.withSampleData()
        let all = try repo.fetchAllSorted()
        XCTAssertLessThan(all[0].sortOrder, all[1].sortOrder)
    }
}

// MARK: - AppPreferences Repository

final class InMemoryAppPreferencesRepositoryTests: XCTestCase {

    // MARK: - fetch

    func test_fetch_emptyRepo_returnsNil() throws {
        let repo = InMemoryAppPreferencesRepository()
        XCTAssertNil(try repo.fetch())
    }

    func test_fetch_withPrefs_returnsPrefs() throws {
        let prefs = AppPreferences(hasCompletedSetup: true)
        let repo = InMemoryAppPreferencesRepository(prefs: prefs)
        XCTAssertNotNil(try repo.fetch())
    }

    // MARK: - upsert

    func test_upsert_insertsWhenEmpty() throws {
        let repo = InMemoryAppPreferencesRepository()
        let prefs = AppPreferences(hasCompletedSetup: true)
        try repo.upsert(prefs)
        XCTAssertNotNil(try repo.fetch())
    }

    func test_upsert_updatesExisting() throws {
        let repo = InMemoryAppPreferencesRepository(prefs: AppPreferences())
        var updated = AppPreferences()
        updated.hasCompletedSetup = true
        try repo.upsert(updated)
        XCTAssertEqual(try repo.fetch()?.hasCompletedSetup, true)
    }

    func test_upsert_overwritesPreviousPrefs() throws {
        let repo = InMemoryAppPreferencesRepository(prefs: AppPreferences(preferredLanguageCode: "ar"))
        try repo.upsert(AppPreferences(preferredLanguageCode: "es"))
        XCTAssertEqual(try repo.fetch()?.preferredLanguageCode, "es")
    }

    // MARK: - withDefaults

    func test_withDefaults_hasCompletedSetup_true() throws {
        let repo = InMemoryAppPreferencesRepository.withDefaults()
        XCTAssertEqual(try repo.fetch()?.hasCompletedSetup, true)
    }

    func test_withDefaults_theme_light() throws {
        let repo = InMemoryAppPreferencesRepository.withDefaults()
        XCTAssertEqual(try repo.fetch()?.theme, .light)
    }

    func test_withDefaults_voicePromptsEnabled() throws {
        let repo = InMemoryAppPreferencesRepository.withDefaults()
        XCTAssertEqual(try repo.fetch()?.voicePromptsEnabled, true)
    }
}
