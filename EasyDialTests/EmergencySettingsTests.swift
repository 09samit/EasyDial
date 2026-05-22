//
//  EmergencySettingsTests.swift
//  EasyDialTests
//
//  Tests for EmergencySettings struct — default value and future flag stubs.
//

import XCTest
@testable import EasyDial

final class EmergencySettingsTests: XCTestCase {

    // MARK: - Default constant

    func test_default_isEnabled_true() {
        XCTAssertTrue(EmergencySettings.default.isEnabled)
    }

    func test_default_emergencyPhoneNumber_empty() {
        XCTAssertEqual(EmergencySettings.default.emergencyPhoneNumber, "")
    }

    // MARK: - Custom init

    func test_customInit_disabled_withPhone() {
        let settings = EmergencySettings(isEnabled: false, emergencyPhoneNumber: "112")
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.emergencyPhoneNumber, "112")
    }

    func test_customInit_enabled_withE164Phone() {
        let settings = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "+14155550911")
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.emergencyPhoneNumber, "+14155550911")
    }

    // MARK: - Future stubs always false

    func test_futureSMSAlerts_alwaysFalse() {
        XCTAssertFalse(EmergencySettings.default.futureSMSAlertsEnabled)
    }

    func test_futureLocationSharing_alwaysFalse() {
        XCTAssertFalse(EmergencySettings.default.futureLocationSharingEnabled)
    }

    func test_futureEmergencyAlerts_alwaysFalse() {
        XCTAssertFalse(EmergencySettings.default.futureEmergencyAlertsEnabled)
    }

    // MARK: - Equatable

    func test_equatable_sameValues_equal() {
        let a = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "911")
        let b = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "911")
        XCTAssertEqual(a, b)
    }

    func test_equatable_differentEnabled_notEqual() {
        let a = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "911")
        let b = EmergencySettings(isEnabled: false, emergencyPhoneNumber: "911")
        XCTAssertNotEqual(a, b)
    }

    func test_equatable_differentPhone_notEqual() {
        let a = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "911")
        let b = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "112")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Mutation

    func test_mutation_toggleEnabled() {
        var settings = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "911")
        settings.isEnabled = false
        XCTAssertFalse(settings.isEnabled)
    }

    func test_mutation_changePhone() {
        var settings = EmergencySettings(isEnabled: true, emergencyPhoneNumber: "911")
        settings.emergencyPhoneNumber = "112"
        XCTAssertEqual(settings.emergencyPhoneNumber, "112")
    }
}
