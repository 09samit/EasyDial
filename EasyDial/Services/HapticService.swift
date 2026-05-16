//
//  HapticService.swift
//  EasyDial
//
//  Soft feedback for routine actions; strong feedback for SOS confirmation.
//

import UIKit

final class HapticService {
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        softImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
    }

    func softTap() {
        softImpact.impactOccurred(intensity: 0.85)
    }

    func sosActivated() {
        notification.notificationOccurred(.error)
        rigidImpact.impactOccurred(intensity: 1.0)
    }
}
