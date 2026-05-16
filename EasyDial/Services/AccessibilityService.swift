//
//  AccessibilityService.swift
//  EasyDial
//
//  Reads system accessibility settings to tune motion and transparency (Reduce Motion / Reduce Transparency).
//

import SwiftUI
import UIKit

final class AccessibilityService {
    var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    var isDifferentiateWithoutColorEnabled: Bool {
        UIAccessibility.shouldDifferentiateWithoutColor
    }

    /// Preferred animation for transitions when Reduce Motion is off.
    func preferredAnimation(duration: Double = 0.22) -> Animation? {
        isReduceMotionEnabled ? nil : .easeInOut(duration: duration)
    }
}
