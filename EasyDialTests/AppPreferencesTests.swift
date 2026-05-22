//
//  AppPreferencesTests.swift
//  EasyDialTests
//
//  Tests for AppPreferences computed properties: theme, emergencySettings,
//  sanitizedEmergencyPhoneNumber, and default initialization.
//

import XCTest
@testable import EasyDial

final class AppPreferencesTests: XCTestCase {

    // MARK: - Default initializer

    func test_defaultInit_hasCompletedSetup_false() {
        let prefs = AppPreferences()
        XCTAssertFalse(prefs.hasCompletedSetup)
    }

    func test_defaultInit_theme_light() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.theme, .light)
    }

    func test_defaultInit_voicePromptsEnabled_true() {
        let prefs = AppPreferences()
        XCTAssertTrue(prefs.voicePromptsEnabled)
    }

    func test_defaultInit_sosEnabled_true() {
        let prefs = AppPreferences()
        XCTAssertTrue(prefs.sosEnabled)
    }

    func test_defaultInit_preferredLanguageCode_en() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.preferredLanguageCode, "en")
    }

    func test_defaultInit_dynamicTypeSizeRaw_nil() {
        let prefs = AppPreferences()
        XCTAssertNil(prefs.dynamicTypeSizeRaw)
    }

    // MARK: - theme computed property

    func test_theme_get_light() {
        let prefs = AppPreferences(themeRaw: "light")
        XCTAssertEqual(prefs.theme, .light)
    }

    func test_theme_get_dark() {
        let prefs = AppPreferences(themeRaw: "dark")
        XCTAssertEqual(prefs.theme, .dark)
    }

    func test_theme_get_highContrast() {
        let prefs = AppPreferences(themeRaw: "highContrast")
        XCTAssertEqual(prefs.theme, .highContrast)
    }

    func test_theme_get_unknownRaw_fallsBackToLight() {
        let prefs = AppPreferences(themeRaw: "sepia")
        XCTAssertEqual(prefs.theme, .light)
    }

    func test_theme_get_emptyRaw_fallsBackToLight() {
        let prefs = AppPreferences(themeRaw: "")
        XCTAssertEqual(prefs.theme, .light)
    }

    func test_theme_set_updateRaw() {
        var prefs = AppPreferences()
        prefs.theme = .dark
        XCTAssertEqual(prefs.themeRaw, "dark")
    }

    func test_theme_set_highContrast_updateRaw() {
        var prefs = AppPreferences()
        prefs.theme = .highContrast
        XCTAssertEqual(prefs.themeRaw, "highContrast")
    }

    // MARK: - emergencySettings computed property

    func test_emergencySettings_get_reflectsSosAndPhone() {
        let prefs = AppPreferences(sosEnabled: true, emergencyPhoneNumber: "911")
        let settings = prefs.emergencySettings
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.emergencyPhoneNumber, "911")
    }

    func test_emergencySettings_get_disabled() {
        let prefs = AppPreferences(sosEnabled: false, emergencyPhoneNumber: "")
        XCTAssertFalse(prefs.emergencySettings.isEnabled)
    }

    func test_emergencySettings_set_updatesPrefs() {
        var prefs = AppPreferences()
        prefs.emergencySettings = EmergencySettings(isEnabled: false, emergencyPhoneNumber: "112")
        XCTAssertFalse(prefs.sosEnabled)
        XCTAssertEqual(prefs.emergencyPhoneNumber, "112")
    }

    // MARK: - sanitizedEmergencyPhoneNumber

    func test_sanitizedEmergencyPhone_clean() {
        let prefs = AppPreferences(emergencyPhoneNumber: "+14155550100")
        XCTAssertEqual(prefs.sanitizedEmergencyPhoneNumber, "+14155550100")
    }

    func test_sanitizedEmergencyPhone_withFormatting() {
        let prefs = AppPreferences(emergencyPhoneNumber: "(415) 555-0100")
        XCTAssertEqual(prefs.sanitizedEmergencyPhoneNumber, "4155550100")
    }

    func test_sanitizedEmergencyPhone_emptyString() {
        let prefs = AppPreferences(emergencyPhoneNumber: "")
        XCTAssertEqual(prefs.sanitizedEmergencyPhoneNumber, "")
    }

    func test_sanitizedEmergencyPhone_whitespaceOnly() {
        let prefs = AppPreferences(emergencyPhoneNumber: "   ")
        XCTAssertEqual(prefs.sanitizedEmergencyPhoneNumber, "")
    }
}
