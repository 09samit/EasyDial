//
//  AppLanguageTests.swift
//  EasyDialTests
//
//  Tests for AppLanguage.resolved() and nativeTitle display strings.
//

import XCTest
@testable import EasyDial

final class AppLanguageTests: XCTestCase {

    // MARK: - resolved(from:)

    func test_resolved_english() {
        XCTAssertEqual(AppLanguage.resolved(from: "en"), .english)
    }

    func test_resolved_arabic() {
        XCTAssertEqual(AppLanguage.resolved(from: "ar"), .arabic)
    }

    func test_resolved_spanish() {
        XCTAssertEqual(AppLanguage.resolved(from: "es"), .spanish)
    }

    func test_resolved_hindi() {
        XCTAssertEqual(AppLanguage.resolved(from: "hi"), .hindi)
    }

    func test_resolved_unknownCode_fallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.resolved(from: "fr"), .english)
    }

    func test_resolved_emptyCode_fallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.resolved(from: ""), .english)
    }

    func test_resolved_caseSensitive_uppercaseNotRecognized() {
        // Codes are stored lowercase; uppercase should fall back to English
        XCTAssertEqual(AppLanguage.resolved(from: "EN"), .english)
    }

    func test_resolved_legacyCode_notRecognized_fallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.resolved(from: "zh-Hans"), .english)
    }

    // MARK: - nativeTitle

    func test_nativeTitle_english() {
        XCTAssertEqual(AppLanguage.english.nativeTitle, "English")
    }

    func test_nativeTitle_arabic() {
        XCTAssertEqual(AppLanguage.arabic.nativeTitle, "العربية")
    }

    func test_nativeTitle_spanish() {
        XCTAssertEqual(AppLanguage.spanish.nativeTitle, "Español")
    }

    func test_nativeTitle_hindi() {
        XCTAssertEqual(AppLanguage.hindi.nativeTitle, "हिन्दी")
    }

    // MARK: - rawValue / id

    func test_rawValue_english() {
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
    }

    func test_id_matchesRawValue() {
        for lang in AppLanguage.allCases {
            XCTAssertEqual(lang.id, lang.rawValue)
        }
    }

    // MARK: - allCases

    func test_allCases_containsFourLanguages() {
        XCTAssertEqual(AppLanguage.allCases.count, 4)
    }

    func test_allCases_containsAllExpected() {
        let expected: Set<AppLanguage> = [.english, .arabic, .spanish, .hindi]
        XCTAssertEqual(Set(AppLanguage.allCases), expected)
    }
}
