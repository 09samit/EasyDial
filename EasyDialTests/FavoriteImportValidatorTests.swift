//
//  FavoriteImportValidatorTests.swift
//  EasyDialTests
//
//  Tests for FavoriteImportValidator — capacity checks and duplicate detection.
//

import XCTest
@testable import EasyDial

final class FavoriteImportValidatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeContact(id: String? = nil, phone: String = "5550000") -> FavoriteContact {
        FavoriteContact(
            sortOrder: 0,
            displayName: "Test",
            relationshipLabel: "",
            phoneNumber: phone,
            cnContactIdentifier: id
        )
    }

    // MARK: - canAdd

    func test_canAdd_emptyList_underLimit() {
        let validator = FavoriteImportValidator(favorites: [], limit: 5)
        XCTAssertTrue(validator.canAdd)
    }

    func test_canAdd_atLimit_false() {
        let contacts = (0..<5).map { makeContact(id: "id\($0)", phone: "555000\($0)") }
        let validator = FavoriteImportValidator(favorites: contacts, limit: 5)
        XCTAssertFalse(validator.canAdd)
    }

    func test_canAdd_belowLimit_true() {
        let contacts = [makeContact(id: "id1", phone: "5550001")]
        let validator = FavoriteImportValidator(favorites: contacts, limit: 5)
        XCTAssertTrue(validator.canAdd)
    }

    // MARK: - limit clamping

    func test_limitClampedToOne_whenZeroProvided() {
        let validator = FavoriteImportValidator(favorites: [], limit: 0)
        // limit is clamped to max(1,0)=1; with 0 contacts we should be able to add
        XCTAssertTrue(validator.canAdd)
    }

    func test_limitClampedToOne_whenNegativeProvided() {
        let validator = FavoriteImportValidator(favorites: [], limit: -5)
        XCTAssertTrue(validator.canAdd)
    }

    func test_limitClampedToOne_oneContactAtLimit() {
        let validator = FavoriteImportValidator(
            favorites: [makeContact(id: "id1")],
            limit: 0
        )
        XCTAssertFalse(validator.canAdd)
    }

    // MARK: - issue: atFavoriteLimit

    func test_issue_atLimit_returnsAtFavoriteLimit() {
        let contacts = (0..<3).map { makeContact(id: "id\($0)", phone: "555000\($0)") }
        let validator = FavoriteImportValidator(favorites: contacts, limit: 3)
        let issue = validator.issue(contactID: "newID", sanitizedPhone: "9990000")
        XCTAssertEqual(issue, .atFavoriteLimit)
    }

    // MARK: - issue: duplicateContact

    func test_issue_duplicateContact_sameID() {
        let contact = makeContact(id: "abc-123", phone: "5550001")
        let validator = FavoriteImportValidator(favorites: [contact], limit: 10)
        XCTAssertEqual(
            validator.issue(contactID: "abc-123", sanitizedPhone: "9990000"),
            .duplicateContact
        )
    }

    func test_issue_duplicateContact_differentPhone_stillDuplicate() {
        let contact = makeContact(id: "abc-123", phone: "5550001")
        let validator = FavoriteImportValidator(favorites: [contact], limit: 10)
        XCTAssertEqual(
            validator.issue(contactID: "abc-123", sanitizedPhone: "5550002"),
            .duplicateContact
        )
    }

    // MARK: - issue: duplicatePhone

    func test_issue_duplicatePhone_sameNumber() {
        let contact = makeContact(id: "id1", phone: "5550001")
        let validator = FavoriteImportValidator(favorites: [contact], limit: 10)
        XCTAssertEqual(
            validator.issue(contactID: "different-id", sanitizedPhone: "5550001"),
            .duplicatePhone
        )
    }

    func test_issue_emptyPhone_notDuplicatePhone() {
        // An empty sanitized phone must NOT trigger duplicatePhone
        // even if existing contacts have empty phones.
        let contact = makeContact(id: "id1", phone: "")
        let validator = FavoriteImportValidator(favorites: [contact], limit: 10)
        // Empty phone is excluded from the set so checking for "" should not match
        let issue = validator.issue(contactID: "new-id", sanitizedPhone: "")
        XCTAssertNil(issue)
    }

    // MARK: - issue: nil (no problem)

    func test_issue_noConflict_returnsNil() {
        let contact = makeContact(id: "id1", phone: "5550001")
        let validator = FavoriteImportValidator(favorites: [contact], limit: 10)
        XCTAssertNil(validator.issue(contactID: "new-id", sanitizedPhone: "5550002"))
    }

    func test_issue_contactWithNilID_notExcluded() {
        // A contact without a cnContactIdentifier should not block an import with a real ID.
        let existing = FavoriteContact(
            sortOrder: 0, displayName: "Ghost",
            relationshipLabel: "", phoneNumber: "5550001",
            cnContactIdentifier: nil
        )
        let validator = FavoriteImportValidator(favorites: [existing], limit: 10)
        XCTAssertNil(validator.issue(contactID: "real-cn-id", sanitizedPhone: "5550002"))
    }

    // MARK: - Priority: atFavoriteLimit > duplicateContact > duplicatePhone

    func test_issue_priority_limitBeforeDuplicate() {
        let contacts = (0..<3).map { makeContact(id: "id\($0)", phone: "555000\($0)") }
        let validator = FavoriteImportValidator(favorites: contacts, limit: 3)
        // Would also be duplicate but limit takes priority
        let issue = validator.issue(contactID: "id0", sanitizedPhone: "5550000")
        XCTAssertEqual(issue, .atFavoriteLimit)
    }
}
