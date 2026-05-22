//
//  SetupViewModelTests.swift
//  EasyDialTests
//
//  Tests for SetupViewModel: step navigation, draft building,
//  photo/phone updates, and commitDrafts.
//

import XCTest
@testable import EasyDial

@MainActor
final class SetupViewModelTests: XCTestCase {

    private var vm: SetupViewModel!

    override func setUp() {
        super.setUp()
        vm = SetupViewModel()
    }

    // MARK: - advance()

    func test_advance_fromPermissions_goesToPickContacts() {
        vm.step = .permissions
        vm.advance()
        XCTAssertEqual(vm.step, .pickContacts)
    }

    func test_advance_sequentialThroughAllSteps() {
        let allSteps = SetupViewModel.Step.ordered
        vm.step = .permissions
        for expected in allSteps.dropFirst() {
            vm.advance()
            XCTAssertEqual(vm.step, expected)
        }
    }

    func test_advance_fromFinish_staysAtFinish() {
        vm.step = .finish
        vm.advance()
        XCTAssertEqual(vm.step, .finish)
    }

    // MARK: - goBack()

    func test_goBack_fromPickContacts_goesToPermissions() {
        vm.step = .pickContacts
        vm.goBack()
        XCTAssertEqual(vm.step, .permissions)
    }

    func test_goBack_fromPermissions_staysAtPermissions() {
        vm.step = .permissions
        vm.goBack()
        XCTAssertEqual(vm.step, .permissions)
    }

    func test_goBack_fromFinish_goesToLanguage() {
        vm.step = .finish
        vm.goBack()
        XCTAssertEqual(vm.step, .language)
    }

    func test_advance_then_goBack_returnsToPrevious() {
        vm.step = .pickContacts
        vm.advance()
        vm.goBack()
        XCTAssertEqual(vm.step, .pickContacts)
    }

    // MARK: - Step.ordered

    func test_orderedSteps_count() {
        XCTAssertEqual(SetupViewModel.Step.ordered.count, 7)
    }

    func test_orderedSteps_firstIsPermissions() {
        XCTAssertEqual(SetupViewModel.Step.ordered.first, .permissions)
    }

    func test_orderedSteps_lastIsFinish() {
        XCTAssertEqual(SetupViewModel.Step.ordered.last, .finish)
    }

    // MARK: - rebuildDraftsFromSelection

    private func makeImported(id: String, name: String, phones: [String] = ["555000"]) -> ImportedContact {
        ImportedContact(
            id: id,
            givenName: name,
            familyName: "",
            organizationName: "",
            phoneNumbers: phones,
            thumbnailImageData: nil,
            anonymousDisplayLabel: "Unknown"
        )
    }

    func test_rebuildDrafts_emptySelection_clearsDrafts() {
        vm.importedContacts = [makeImported(id: "a", name: "Alice")]
        vm.selectedImports = []
        vm.rebuildDraftsFromSelection()
        XCTAssertTrue(vm.drafts.isEmpty)
    }

    func test_rebuildDrafts_singleSelection_createsDraft() {
        let contact = makeImported(id: "a", name: "Alice", phones: ["5550001"])
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()
        XCTAssertEqual(vm.drafts.count, 1)
        XCTAssertEqual(vm.drafts.first?.displayName, "Alice")
        XCTAssertEqual(vm.drafts.first?.phoneNumber, "5550001")
        XCTAssertEqual(vm.drafts.first?.cnContactIdentifier, "a")
    }

    func test_rebuildDrafts_preservesExistingDraftData() {
        let contact = makeImported(id: "a", name: "Alice", phones: ["5550001"])
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()

        // Simulate user editing phone number
        let draftID = vm.drafts[0].id
        vm.drafts[0].phoneNumber = "9990000"

        // Rebuild — should preserve edited phone
        vm.rebuildDraftsFromSelection()
        XCTAssertEqual(vm.drafts.first?.id, draftID)
        XCTAssertEqual(vm.drafts.first?.phoneNumber, "9990000")
    }

    func test_rebuildDrafts_preservesExistingDraftPhoto() {
        let contact = makeImported(id: "a", name: "Alice")
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()

        // Simulate user setting photo
        vm.drafts[0].photoData = Data("photo".utf8)

        vm.rebuildDraftsFromSelection()
        XCTAssertEqual(vm.drafts.first?.photoData, Data("photo".utf8))
    }

    func test_rebuildDrafts_deselectedContact_removedFromDrafts() {
        let a = makeImported(id: "a", name: "Alice")
        let b = makeImported(id: "b", name: "Bob")
        vm.importedContacts = [a, b]
        vm.selectedImports = ["a", "b"]
        vm.rebuildDraftsFromSelection()
        XCTAssertEqual(vm.drafts.count, 2)

        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()
        XCTAssertEqual(vm.drafts.count, 1)
        XCTAssertEqual(vm.drafts.first?.cnContactIdentifier, "a")
    }

    func test_rebuildDrafts_selectedImports_trimmedToOrdered() {
        // After rebuild, selectedImports reflects only what actually fit
        let contacts = (0..<3).map { makeImported(id: "id\($0)", name: "Contact \($0)") }
        vm.importedContacts = contacts
        vm.selectedImports = Set(contacts.map(\.id))
        vm.rebuildDraftsFromSelection()
        // All 3 selected; selectedImports should still have 3
        XCTAssertEqual(vm.selectedImports.count, 3)
    }

    func test_rebuildDrafts_updatesNameFromImport() {
        let contact = makeImported(id: "a", name: "Alice")
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()

        // Import changes name (simulating refresh)
        vm.importedContacts = [makeImported(id: "a", name: "Alicia")]
        vm.rebuildDraftsFromSelection()
        XCTAssertEqual(vm.drafts.first?.displayName, "Alicia")
    }

    func test_rebuildDrafts_emptyPhoneInDraft_replacedFromImport() {
        let contact = makeImported(id: "a", name: "Alice", phones: ["5550001"])
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()

        // Clear phone in draft to simulate erasure
        vm.drafts[0].phoneNumber = ""
        vm.rebuildDraftsFromSelection()

        // Should refill from import
        XCTAssertEqual(vm.drafts.first?.phoneNumber, "5550001")
    }

    // MARK: - updateDraft

    func test_updateDraft_changesPhoneNumber() {
        let contact = makeImported(id: "a", name: "Alice", phones: ["5550001"])
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()

        let draftID = vm.drafts[0].id
        vm.updateDraft(id: draftID, phone: "9990000")
        XCTAssertEqual(vm.drafts.first?.phoneNumber, "9990000")
    }

    func test_updateDraft_unknownID_noOp() {
        XCTAssertNoThrow(vm.updateDraft(id: UUID(), phone: "9990000"))
    }

    // MARK: - commitDrafts

    func test_commitDrafts_insertsContactsIntoStore() throws {
        let store = AppStore(
            contactRepo: InMemoryFavoriteContactRepository(),
            prefsRepo: InMemoryAppPreferencesRepository(),
            photoStorage: InMemoryContactPhotoStorage()
        )
        store.bootstrap()

        let contact = makeImported(id: "a", name: "Alice", phones: ["5550001"])
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()

        try vm.commitDrafts(store: store, locale: Locale(identifier: "en"))
        XCTAssertEqual(store.favorites.count, 1)
        XCTAssertEqual(store.favorites.first?.displayName, "Alice")
    }

    func test_commitDrafts_setsHasCompletedSetup_true() throws {
        let store = AppStore(
            contactRepo: InMemoryFavoriteContactRepository(),
            prefsRepo: InMemoryAppPreferencesRepository(),
            photoStorage: InMemoryContactPhotoStorage()
        )
        store.bootstrap()

        try vm.commitDrafts(store: store, locale: Locale(identifier: "en"))
        XCTAssertTrue(store.preferences?.hasCompletedSetup == true)
    }

    func test_commitDrafts_sanitizesPhone() throws {
        let store = AppStore(
            contactRepo: InMemoryFavoriteContactRepository(),
            prefsRepo: InMemoryAppPreferencesRepository(),
            photoStorage: InMemoryContactPhotoStorage()
        )
        store.bootstrap()

        let contact = makeImported(id: "a", name: "Alice", phones: ["(415) 555-0100"])
        vm.importedContacts = [contact]
        vm.selectedImports = ["a"]
        vm.rebuildDraftsFromSelection()

        try vm.commitDrafts(store: store, locale: Locale(identifier: "en"))
        XCTAssertEqual(store.favorites.first?.phoneNumber, "4155550100")
    }

    func test_commitDrafts_assignsSequentialSortOrders() throws {
        let store = AppStore(
            contactRepo: InMemoryFavoriteContactRepository(),
            prefsRepo: InMemoryAppPreferencesRepository(),
            photoStorage: InMemoryContactPhotoStorage()
        )
        store.bootstrap()

        vm.importedContacts = [
            makeImported(id: "a", name: "Alice", phones: ["5550001"]),
            makeImported(id: "b", name: "Bob", phones: ["5550002"]),
        ]
        vm.selectedImports = ["a", "b"]
        vm.rebuildDraftsFromSelection()

        try vm.commitDrafts(store: store, locale: Locale(identifier: "en"))
        let orders = store.favorites.map(\.sortOrder).sorted()
        XCTAssertEqual(orders, [0, 1])
    }
}
