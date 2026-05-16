//
//  EmergencySOSView.swift
//  EasyDial
//
//  Long-press (~1.75s) SOS bar with visible hold progress, haptics, and speech before dialing.
//

import SwiftUI

struct EmergencySOSView: View {
    let colors: ThemeColors
    let isEnabled: Bool
    let voicePromptsEnabled: Bool
    let languageCode: String
    let emergencyNumber: String
    /// Reports dialing failures to the caller for human-readable alerts.
    let onEmergencyCallResult: (String?) -> Void

    @Environment(\.appServices) private var services
    @Environment(\.locale) private var locale

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pressing = false
    @State private var holdProgress: CGFloat = 0

    /// Slightly under 2s so system gesture latency still feels like “about two seconds”.
    private let holdDuration: Double = 1.75

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(sosFill)
                    .frame(height: colors.accessibilityEmphasis ? 80 : 76)
                    .overlay {
                        if colors.accessibilityEmphasis {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(colors.emergency, lineWidth: colors.cardStrokeWidth)
                        }
                    }

                if pressing, !reduceMotion {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(colors.emergency.opacity(colors.accessibilityEmphasis ? 0.35 : 0.5))
                            .frame(width: max(0, geo.size.width * holdProgress))
                    }
                    .allowsHitTesting(false)
                }

                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(colors.accessibilityEmphasis ? .title.weight(.bold) : .title2.weight(.bold))
                        .foregroundStyle(sosLabelColor)
                        .accessibilityHidden(true)
                    Text(L10n.string("sos.title", locale: locale))
                        .font(colors.accessibilityEmphasis ? .title.weight(.bold) : .title2.weight(.bold))
                        .foregroundStyle(sosLabelColor)
                }
                .frame(maxWidth: .infinity)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: pressing)

            Text(L10n.string("sos.instructions", locale: locale))
                .font(colors.accessibilityEmphasis ? .body.weight(.bold) : .body.weight(.semibold))
                .foregroundStyle(colors.accessibilityEmphasis ? colors.primaryText : colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L10n.string("a11y.sos_label", locale: locale)))
        .accessibilityHint(Text(L10n.string("a11y.sos_hint", locale: locale)))
        .accessibilityAddTraits(.startsMediaSession)
        .onLongPressGesture(
            minimumDuration: holdDuration,
            pressing: { isPressing in
                pressing = isPressing
                if isPressing {
                    holdProgress = 0
                    if reduceMotion {
                        holdProgress = 1
                    } else {
                        withAnimation(.linear(duration: holdDuration)) {
                            holdProgress = 1
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.12)) {
                        holdProgress = 0
                    }
                }
            },
            perform: activate
        )
        .disabled(!isEnabled)
    }

    private var sosFill: Color {
        if colors.accessibilityEmphasis {
            return colors.background.opacity(pressing ? 0.85 : 1)
        }
        return colors.emergency.opacity(pressing ? 0.35 : 0.18)
    }

    private var sosLabelColor: Color {
        colors.accessibilityEmphasis ? colors.onEmergency : colors.emergency
    }

    private func activate() {
        guard isEnabled else { return }
        holdProgress = 1
        services.haptics.sosActivated()
        services.speech.speakEmergencyActivated(
            languageCode: languageCode,
            voicePromptsEnabled: voicePromptsEnabled
        ) { [services, emergencyNumber, locale] in
            let message = services.calls.placeCallMessageIfFailed(emergencyNumber, locale: locale)
            onEmergencyCallResult(message)
        }
    }
}

#Preview {
    EmergencySOSView(
        colors: ThemeColors.palette(for: .light),
        isEnabled: true,
        voicePromptsEnabled: true,
        languageCode: "en",
        emergencyNumber: "911",
        onEmergencyCallResult: { _ in }
    )
    .padding()
    .environment(\.appServices, AppServices())
    .environment(\.locale, Locale(identifier: "en"))
}
