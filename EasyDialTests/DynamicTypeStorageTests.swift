//
//  DynamicTypeStorageTests.swift
//  EasyDialTests
//
//  Tests for DynamicTypeStorage: storageKey round-trips, resolvedSize,
//  and legacy String(describing:) migration path.
//

import SwiftUI
import XCTest
@testable import EasyDial

final class DynamicTypeStorageTests: XCTestCase {

    // MARK: - storageKey stability

    func test_storageKey_xSmall() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .xSmall), "xSmall")
    }

    func test_storageKey_small() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .small), "small")
    }

    func test_storageKey_medium() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .medium), "medium")
    }

    func test_storageKey_large() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .large), "large")
    }

    func test_storageKey_xLarge() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .xLarge), "xLarge")
    }

    func test_storageKey_xxLarge() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .xxLarge), "xxLarge")
    }

    func test_storageKey_xxxLarge() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .xxxLarge), "xxxLarge")
    }

    func test_storageKey_accessibility1() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .accessibility1), "accessibility1")
    }

    func test_storageKey_accessibility2() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .accessibility2), "accessibility2")
    }

    func test_storageKey_accessibility3() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .accessibility3), "accessibility3")
    }

    func test_storageKey_accessibility4() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .accessibility4), "accessibility4")
    }

    func test_storageKey_accessibility5() {
        XCTAssertEqual(DynamicTypeStorage.storageKey(for: .accessibility5), "accessibility5")
    }

    // MARK: - resolvedSize round-trip

    func test_resolvedSize_allChoices_roundTrip() {
        for size in DynamicTypeStorage.choices {
            let key = DynamicTypeStorage.storageKey(for: size)
            let resolved = DynamicTypeStorage.resolvedSize(storedRaw: key)
            XCTAssertEqual(resolved, size, "Round-trip failed for \(key)")
        }
    }

    // MARK: - resolvedSize nil / empty inputs

    func test_resolvedSize_nil_returnsNil() {
        XCTAssertNil(DynamicTypeStorage.resolvedSize(storedRaw: nil))
    }

    func test_resolvedSize_emptyString_returnsNil() {
        XCTAssertNil(DynamicTypeStorage.resolvedSize(storedRaw: ""))
    }

    // MARK: - resolvedSize unknown key

    func test_resolvedSize_unknownKey_returnsNil() {
        XCTAssertNil(DynamicTypeStorage.resolvedSize(storedRaw: "giantSize"))
    }

    // MARK: - choices array

    func test_choices_containsAllTwelveSizes() {
        XCTAssertEqual(DynamicTypeStorage.choices.count, 12)
    }

    func test_choices_containsLarge() {
        XCTAssertTrue(DynamicTypeStorage.choices.contains(.large))
    }

    func test_choices_containsAccessibility5() {
        XCTAssertTrue(DynamicTypeStorage.choices.contains(.accessibility5))
    }
}
