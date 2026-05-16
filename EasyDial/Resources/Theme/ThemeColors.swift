//
//  ThemeColors.swift
//  EasyDial
//
//  Central color tokens for Light, Dark, and High Contrast modes (healthcare utility aesthetic).
//

import SwiftUI

/// Semantic palette resolved per `AppTheme`. Avoid hard-coded colors in views—use these tokens.
struct ThemeColors {
    let background: Color
    let cardBackground: Color
    /// Background for inset grouped lists (Settings, Favorite people).
    let groupedSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let primaryButton: Color
    /// Label color on `primaryButton` fills (must meet contrast on `primaryButton`).
    let onPrimaryButton: Color
    let success: Color
    let emergency: Color
    /// Label/icon on solid `emergency` fills (high contrast SOS bar).
    let onEmergency: Color
    let divider: Color
    /// Hint text in empty text fields (must stay legible on `groupedSurface` / field backgrounds).
    let placeholderText: Color
    /// Stroke around contact cards and grouped surfaces.
    let cardStrokeWidth: CGFloat
    /// High-contrast mode: heavier type, yellow-on-black chrome (distinct from calm Light).
    let accessibilityEmphasis: Bool

    // High Contrast mockup: black field, #FFFF00 accents, white titles, red SOS.
    private static let hcYellow = Color(red: 1, green: 1, blue: 0)
    private static let hcRed = Color(red: 1, green: 0, blue: 0)

    static func palette(for theme: AppTheme) -> ThemeColors {
        switch theme {
        case .light:
            return ThemeColors(
                background: Color(red: 0.969, green: 0.957, blue: 0.929), // #F7F4ED warm cream
                cardBackground: Color.white,
                groupedSurface: Color.white,
                primaryText: Color(red: 0.122, green: 0.122, blue: 0.122), // #1F1F1F
                secondaryText: Color(red: 0.419, green: 0.419, blue: 0.419), // #6B6B6B
                primaryButton: Color(red: 0.082, green: 0.435, blue: 0.361), // #156F5C teal
                onPrimaryButton: .white,
                success: Color(red: 0.180, green: 0.490, blue: 0.196), // #2E7D32
                emergency: Color(red: 0.776, green: 0.157, blue: 0.157), // #C62828
                onEmergency: Color(red: 0.776, green: 0.157, blue: 0.157),
                divider: Color.black.opacity(0.08),
                placeholderText: Color(red: 0.419, green: 0.419, blue: 0.419),
                cardStrokeWidth: 1,
                accessibilityEmphasis: false
            )
        case .dark:
            return ThemeColors(
                background: Color(red: 0.176, green: 0.216, blue: 0.282), // #2D3748
                cardBackground: Color(red: 0.239, green: 0.290, blue: 0.361), // #3D4A5C
                groupedSurface: Color(red: 0.239, green: 0.290, blue: 0.361),
                primaryText: Color(red: 0.969, green: 0.980, blue: 0.988), // #F7FAFC
                secondaryText: Color(red: 0.796, green: 0.835, blue: 0.878), // #CBD5E0
                primaryButton: Color(red: 0.310, green: 0.820, blue: 0.773), // #4FD1C5
                onPrimaryButton: Color(red: 0.102, green: 0.125, blue: 0.173), // #1A202C
                success: Color(red: 0.408, green: 0.820, blue: 0.569), // #68D391
                emergency: Color(red: 0.988, green: 0.506, blue: 0.506), // #FC8181
                onEmergency: Color(red: 0.988, green: 0.506, blue: 0.506),
                divider: Color.white.opacity(0.38),
                placeholderText: Color(red: 0.710, green: 0.769, blue: 0.835), // #B5C4D5
                cardStrokeWidth: 2,
                accessibilityEmphasis: false
            )
        case .highContrast:
            return ThemeColors(
                background: .black,
                cardBackground: .black,
                groupedSurface: .black,
                primaryText: .white,
                secondaryText: hcYellow,
                primaryButton: hcYellow,
                onPrimaryButton: .black,
                success: hcYellow,
                emergency: hcRed,
                onEmergency: hcRed,
                divider: Color.white.opacity(0.55),
                placeholderText: Color.white.opacity(0.82),
                cardStrokeWidth: 3,
                accessibilityEmphasis: true
            )
        }
    }
}
