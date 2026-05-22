//
//  FavoriteContactTests.swift
//  EasyDialTests
//
//  Tests for FavoriteContact struct — initialization, Hashable, hiddenRelationshipLabel.
//

import XCTest
@testable import EasyDial

final class FavoriteContactTests: XCTestCase {

    // MARK: - Initialization

    func test_init_defaultID_unique() {
        let a = FavoriteContact(sortOrder: 0, displayName: "A", relationshipLabel: "", phoneNumber: "555")
        let b = FavoriteContact(sortOrder: 0, displayName: "A", relationshipLabel: "", phoneNumber: "555")
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_init_customID_preserved() {
        let id = UUID()
        let contact = FavoriteContact(id: id, sortOrder: 0, displayName: "Alice", relationshipLabel: "", phoneNumber: "555")
        XCTAssertEqual(contact.id, id)
    }

    func test_init_sortOrder_preserved() {
        let contact = FavoriteContact(sortOrder: 7, displayName: "A", relationshipLabel: "", phoneNumber: "555")
        XCTAssertEqual(contact.sortOrder, 7)
    }

    func test_init_cnContactIdentifier_defaultNil() {
        let contact = FavoriteContact(sortOrder: 0, displayName: "A", relationshipLabel: "", phoneNumber: "555")
        XCTAssertNil(contact.cnContactIdentifier)
    }

    func test_init_cnContactIdentifier_customValue() {
        let contact = FavoriteContact(
            sortOrder: 0, displayName: "A", relationshipLabel: "", phoneNumber: "555",
            cnContactIdentifier: "abc-123"
        )
        XCTAssertEqual(contact.cnContactIdentifier, "abc-123")
    }

    func test_init_createdAt_defaultIsNow() {
        let before = Date()
        let contact = FavoriteContact(sortOrder: 0, displayName: "A", relationshipLabel: "", phoneNumber: "555")
        let after = Date()
        XCTAssertGreaterThanOrEqual(contact.createdAt, before)
        XCTAssertLessThanOrEqual(contact.createdAt, after)
    }

    // MARK: - hiddenRelationshipLabel

    func test_hiddenRelationshipLabel_isEmptyString() {
        XCTAssertEqual(FavoriteContact.hiddenRelationshipLabel, "")
    }

    // MARK: - Hashable / Equatable (via Identifiable)

    func test_hashable_sameIDInSet() {
        let id = UUID()
        let a = FavoriteContact(id: id, sortOrder: 0, displayName: "A", relationshipLabel: "", phoneNumber: "555")
        let b = FavoriteContact(id: id, sortOrder: 1, displayName: "B", relationshipLabel: "Mom", phoneNumber: "777")
        var set = Set<FavoriteContact>()
        set.insert(a)
        set.insert(b)
        // Hashable is derived — both have same id so struct equality differs but Hashable may differ
        // FavoriteContact is Hashable (synthesized) — all stored properties matter
        XCTAssertEqual(set.count, 2) // Different sort/display values → different hashes
    }

    func test_hashable_identicalContactsDeduplicatedInSet() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 0)
        let a = FavoriteContact(id: id, sortOrder: 0, displayName: "Alice", relationshipLabel: "", phoneNumber: "555", cnContactIdentifier: nil, createdAt: date)
        let b = FavoriteContact(id: id, sortOrder: 0, displayName: "Alice", relationshipLabel: "", phoneNumber: "555", cnContactIdentifier: nil, createdAt: date)
        var set = Set<FavoriteContact>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Mutation (value semantics)

    func test_mutation_sortOrder_independent() {
        var a = FavoriteContact(sortOrder: 0, displayName: "Alice", relationshipLabel: "", phoneNumber: "555")
        let b = a
        a.sortOrder = 99
        XCTAssertEqual(b.sortOrder, 0)
    }

    func test_mutation_displayName_independent() {
        var a = FavoriteContact(sortOrder: 0, displayName: "Alice", relationshipLabel: "", phoneNumber: "555")
        let b = a
        a.displayName = "Alicia"
        XCTAssertEqual(b.displayName, "Alice")
    }
}
