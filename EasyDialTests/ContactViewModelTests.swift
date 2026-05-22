//
//  ContactViewModelTests.swift
//  EasyDialTests
//
//  Tests for ContactViewModel.validate — name/phone validation logic.
//

import XCTest
@testable import EasyDial

@MainActor
final class ContactViewModelTests: XCTestCase {

    private var vm: ContactViewModel!
    private let locale = Locale(identifier: "en")

    override func setUp() {
        super.setUp()
        vm = ContactViewModel()
    }

    // MARK: - validate: passing

    func test_validate_validNameAndPhone_returnsNil() {
        vm.displayName = "Alice"
        vm.phoneNumber = "5550000"
        XCTAssertNil(vm.validate(locale: locale))
    }

    func test_validate_nameWithWhitespace_valid() {
        vm.displayName = "  Alice  "
        vm.phoneNumber = "5550000"
        XCTAssertNil(vm.validate(locale: locale))
    }

    func test_validate_e164Phone_valid() {
        vm.displayName = "Bob"
        vm.phoneNumber = "+14155550100"
        XCTAssertNil(vm.validate(locale: locale))
    }

    func test_validate_formattedPhone_sanitized_valid() {
        vm.displayName = "Carol"
        vm.phoneNumber = "(415) 555-0100"
        XCTAssertNil(vm.validate(locale: locale))
    }

    // MARK: - validate: empty name

    func test_validate_emptyName_returnsError() {
        vm.displayName = ""
        vm.phoneNumber = "5550000"
        XCTAssertNotNil(vm.validate(locale: locale))
    }

    func test_validate_whitespaceOnlyName_returnsError() {
        vm.displayName = "   "
        vm.phoneNumber = "5550000"
        XCTAssertNotNil(vm.validate(locale: locale))
    }

    func test_validate_emptyName_errorNotSameAsPhoneError() {
        vm.displayName = ""
        vm.phoneNumber = "5550000"
        let nameError = vm.validate(locale: locale)

        vm.displayName = "Alice"
        vm.phoneNumber = ""
        let phoneError = vm.validate(locale: locale)

        XCTAssertNotEqual(nameError, phoneError)
    }

    // MARK: - validate: empty phone

    func test_validate_emptyPhone_returnsError() {
        vm.displayName = "Alice"
        vm.phoneNumber = ""
        XCTAssertNotNil(vm.validate(locale: locale))
    }

    func test_validate_whitespaceOnlyPhone_returnsError() {
        vm.displayName = "Alice"
        vm.phoneNumber = "   "
        XCTAssertNotNil(vm.validate(locale: locale))
    }

    func test_validate_nonDialablePhone_returnsError() {
        vm.displayName = "Alice"
        vm.phoneNumber = "abc"
        XCTAssertNotNil(vm.validate(locale: locale))
    }

    // MARK: - validate: both empty

    func test_validate_bothEmpty_returnsNameError() {
        // Name is validated first — should report name error
        vm.displayName = ""
        vm.phoneNumber = ""
        let error = vm.validate(locale: locale)
        XCTAssertNotNil(error)
    }

    // MARK: - reset

    func test_reset_copiesNameAndPhone() {
        let contact = FavoriteContact(
            sortOrder: 0,
            displayName: "Test User",
            relationshipLabel: "",
            phoneNumber: "5550000"
        )
        let storage = InMemoryContactPhotoStorage()
        vm.reset(from: contact, photoStorage: storage)
        XCTAssertEqual(vm.displayName, "Test User")
        XCTAssertEqual(vm.phoneNumber, "5550000")
    }

    func test_reset_loadsPhoto_whenPresent() throws {
        let id = UUID()
        let contact = FavoriteContact(id: id, sortOrder: 0, displayName: "Test", relationshipLabel: "", phoneNumber: "555")
        let storage = InMemoryContactPhotoStorage()
        try storage.save(Data("photo".utf8), for: id)
        vm.reset(from: contact, photoStorage: storage)
        XCTAssertEqual(vm.photoData, Data("photo".utf8))
    }

    func test_reset_nilPhoto_whenNotPresent() {
        let contact = FavoriteContact(sortOrder: 0, displayName: "Test", relationshipLabel: "", phoneNumber: "555")
        let storage = InMemoryContactPhotoStorage()
        vm.reset(from: contact, photoStorage: storage)
        XCTAssertNil(vm.photoData)
    }

    func test_reset_clearsPhotoChangedFlag() throws {
        let id = UUID()
        let contact = FavoriteContact(id: id, sortOrder: 0, displayName: "Test", relationshipLabel: "", phoneNumber: "555")
        let storage = InMemoryContactPhotoStorage()
        vm.photoChanged = true
        vm.photoRemoved = true
        vm.reset(from: contact, photoStorage: storage)
        XCTAssertFalse(vm.photoChanged)
        XCTAssertFalse(vm.photoRemoved)
    }
}
