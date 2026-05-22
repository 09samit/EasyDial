//
//  InMemoryContactPhotoStorageTests.swift
//  EasyDialTests
//
//  Tests for InMemoryContactPhotoStorage — the test/preview photo storage implementation.
//

import XCTest
@testable import EasyDial

final class InMemoryContactPhotoStorageTests: XCTestCase {

    private var storage: InMemoryContactPhotoStorage!

    override func setUp() {
        super.setUp()
        storage = InMemoryContactPhotoStorage()
    }

    // MARK: - save / load

    func test_save_then_load_returnsData() throws {
        let id = UUID()
        let data = Data("photo".utf8)
        try storage.save(data, for: id)
        XCTAssertEqual(storage.load(for: id), data)
    }

    func test_load_nonExistentID_returnsNil() {
        XCTAssertNil(storage.load(for: UUID()))
    }

    func test_save_overwritesPreviousData() throws {
        let id = UUID()
        try storage.save(Data("first".utf8), for: id)
        try storage.save(Data("second".utf8), for: id)
        XCTAssertEqual(storage.load(for: id), Data("second".utf8))
    }

    // MARK: - delete

    func test_delete_removesData() throws {
        let id = UUID()
        try storage.save(Data("photo".utf8), for: id)
        storage.delete(for: id)
        XCTAssertNil(storage.load(for: id))
    }

    func test_delete_nonExistentID_noOp() {
        // Must not crash
        XCTAssertNoThrow(storage.delete(for: UUID()))
    }

    func test_delete_onlyRemovesTargetID() throws {
        let id1 = UUID()
        let id2 = UUID()
        try storage.save(Data("photo1".utf8), for: id1)
        try storage.save(Data("photo2".utf8), for: id2)
        storage.delete(for: id1)
        XCTAssertNil(storage.load(for: id1))
        XCTAssertNotNil(storage.load(for: id2))
    }

    // MARK: - deleteAll

    func test_deleteAll_clearsAllEntries() throws {
        let id1 = UUID()
        let id2 = UUID()
        try storage.save(Data("a".utf8), for: id1)
        try storage.save(Data("b".utf8), for: id2)
        storage.deleteAll()
        XCTAssertNil(storage.load(for: id1))
        XCTAssertNil(storage.load(for: id2))
    }

    func test_deleteAll_emptyStorage_noOp() {
        XCTAssertNoThrow(storage.deleteAll())
    }

    // MARK: - cleanupOrphanedFiles

    func test_cleanupOrphanedFiles_noOpOnInMemory() throws {
        let id = UUID()
        try storage.save(Data("photo".utf8), for: id)
        // InMemory implementation is a no-op; data should remain untouched
        storage.cleanupOrphanedFiles(validIDs: [])
        XCTAssertNotNil(storage.load(for: id))
    }

    // MARK: - save empty data

    func test_save_emptyData_loadable() throws {
        let id = UUID()
        try storage.save(Data(), for: id)
        XCTAssertEqual(storage.load(for: id), Data())
    }
}
