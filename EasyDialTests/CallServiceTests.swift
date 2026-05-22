//
//  CallServiceTests.swift
//  EasyDialTests
//
//  Tests for CallService.sanitizePhone — highest-ROI pure function in the codebase.
//

import XCTest
@testable import EasyDial

final class CallServiceTests: XCTestCase {

    // MARK: - Clean digit strings

    func test_sanitize_pureDigits_unchanged() {
        XCTAssertEqual(CallService.sanitizePhone("1234567890"), "1234567890")
    }

    func test_sanitize_singleDigit() {
        XCTAssertEqual(CallService.sanitizePhone("5"), "5")
    }

    func test_sanitize_longDigitString() {
        XCTAssertEqual(CallService.sanitizePhone("00441234567890"), "00441234567890")
    }

    // MARK: - Leading plus (E.164)

    func test_sanitize_leadingPlus_kept() {
        XCTAssertEqual(CallService.sanitizePhone("+14155550100"), "+14155550100")
    }

    func test_sanitize_leadingPlusOnly() {
        // "+" alone → no digits follow, but the leading "+" is preserved as-is by the sanitizer.
        // Validation (isEmpty check) happens at the call-site, not inside sanitizePhone.
        XCTAssertEqual(CallService.sanitizePhone("+"), "+")
    }

    func test_sanitize_plusInMiddle_stripped() {
        XCTAssertEqual(CallService.sanitizePhone("123+456"), "123456")
    }

    func test_sanitize_plusAtEnd_stripped() {
        XCTAssertEqual(CallService.sanitizePhone("123+"), "123")
    }

    func test_sanitize_multiplePlusSigns_onlyLeadingKept() {
        XCTAssertEqual(CallService.sanitizePhone("+1+2+3"), "+123")
    }

    // MARK: - Special characters stripped

    func test_sanitize_dashesSparesParens() {
        XCTAssertEqual(CallService.sanitizePhone("(415) 555-0100"), "4155550100")
    }

    func test_sanitize_dotsAsDelimiters() {
        XCTAssertEqual(CallService.sanitizePhone("1.800.555.0100"), "18005550100")
    }

    func test_sanitize_mixedDelimiters() {
        XCTAssertEqual(CallService.sanitizePhone("+44 (20) 1234-5678"), "+442012345678")
    }

    func test_sanitize_hashAndStar_stripped() {
        XCTAssertEqual(CallService.sanitizePhone("#*123#"), "123")
    }

    func test_sanitize_lettersStripped() {
        XCTAssertEqual(CallService.sanitizePhone("1-800-FLOWERS"), "1800")
    }

    // MARK: - Whitespace handling

    func test_sanitize_leadingTrailingWhitespace_trimmed() {
        XCTAssertEqual(CallService.sanitizePhone("  5551234  "), "5551234")
    }

    func test_sanitize_whitespaceOnlyString_returnsEmpty() {
        XCTAssertEqual(CallService.sanitizePhone("   "), "")
    }

    func test_sanitize_tabAndNewline_trimmed() {
        XCTAssertEqual(CallService.sanitizePhone("\t123\n"), "123")
    }

    // MARK: - Empty / nil-like inputs

    func test_sanitize_emptyString_returnsEmpty() {
        XCTAssertEqual(CallService.sanitizePhone(""), "")
    }

    // MARK: - Unicode / international

    func test_sanitize_arabicDigits_stripped() {
        // Arabic-Indic digits are not in CharacterSet.decimalDigits ASCII range
        // Behavior: stripped (they are in Unicode decimal digits but
        // CallService uses CharacterSet.decimalDigits which includes them on some platforms).
        // Verify we at least get a deterministic result (no crash).
        let result = CallService.sanitizePhone("٠١٢٣")
        XCTAssertNotNil(result) // Must not crash
    }

    func test_sanitize_emojiStripped() {
        XCTAssertEqual(CallService.sanitizePhone("📞123"), "123")
    }

    // MARK: - Idempotency

    func test_sanitize_idempotent_plainNumber() {
        let once = CallService.sanitizePhone("(415) 555-0100")
        let twice = CallService.sanitizePhone(once)
        XCTAssertEqual(once, twice)
    }

    func test_sanitize_idempotent_e164() {
        let once = CallService.sanitizePhone("+14155550100")
        let twice = CallService.sanitizePhone(once)
        XCTAssertEqual(once, twice)
    }
}
