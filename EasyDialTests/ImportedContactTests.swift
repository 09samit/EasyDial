//
//  ImportedContactTests.swift
//  EasyDialTests
//
//  Tests for ImportedContact.displayName computed property — name resolution priority.
//

import XCTest
@testable import EasyDial

final class ImportedContactTests: XCTestCase {

    private func makeContact(
        given: String = "",
        family: String = "",
        org: String = "",
        anonymousLabel: String = "Unknown"
    ) -> ImportedContact {
        ImportedContact(
            id: UUID().uuidString,
            givenName: given,
            familyName: family,
            organizationName: org,
            phoneNumbers: ["5550000"],
            thumbnailImageData: nil,
            anonymousDisplayLabel: anonymousLabel
        )
    }

    // MARK: - Full name resolution

    func test_displayName_givenAndFamily() {
        let contact = makeContact(given: "Jane", family: "Doe")
        XCTAssertEqual(contact.displayName, "Jane Doe")
    }

    func test_displayName_givenOnly() {
        let contact = makeContact(given: "Alice", family: "")
        XCTAssertEqual(contact.displayName, "Alice")
    }

    func test_displayName_familyOnly() {
        let contact = makeContact(given: "", family: "Smith")
        XCTAssertEqual(contact.displayName, "Smith")
    }

    // MARK: - Organization fallback

    func test_displayName_noName_usesOrg() {
        let contact = makeContact(given: "", family: "", org: "Acme Corp")
        XCTAssertEqual(contact.displayName, "Acme Corp")
    }

    func test_displayName_spacesOnlyName_usesOrg() {
        let contact = makeContact(given: "  ", family: "  ", org: "Acme Corp")
        XCTAssertEqual(contact.displayName, "Acme Corp")
    }

    // MARK: - Anonymous label fallback

    func test_displayName_noNameNoOrg_usesAnonymousLabel() {
        let contact = makeContact(given: "", family: "", org: "", anonymousLabel: "Unknown Contact")
        XCTAssertEqual(contact.displayName, "Unknown Contact")
    }

    func test_displayName_allEmpty_usesAnonymousLabel() {
        let contact = makeContact(given: "", family: "", org: "", anonymousLabel: "جهة اتصال غير معروفة")
        XCTAssertEqual(contact.displayName, "جهة اتصال غير معروفة")
    }

    // MARK: - Priority: full name > org > anonymous

    func test_displayName_prioritizesFullNameOverOrg() {
        let contact = makeContact(given: "Bob", family: "Jones", org: "SomeOrg")
        XCTAssertEqual(contact.displayName, "Bob Jones")
    }

    func test_displayName_prioritizesOrgOverAnonymous() {
        let contact = makeContact(given: "", family: "", org: "MyCompany", anonymousLabel: "Unknown")
        XCTAssertEqual(contact.displayName, "MyCompany")
    }

    // MARK: - Identifiable

    func test_id_uniquePerInstance() {
        let a = makeContact(given: "Alice")
        let b = makeContact(given: "Alice")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - Hashable

    func test_hashable_sameContactInSet() {
        let contact = makeContact(given: "Alice")
        var set = Set<ImportedContact>()
        set.insert(contact)
        set.insert(contact)
        XCTAssertEqual(set.count, 1)
    }
}
