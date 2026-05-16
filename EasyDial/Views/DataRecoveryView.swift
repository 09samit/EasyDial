//
//  DataRecoveryView.swift
//  EasyDial
//
//  Shown when the SwiftData store cannot be opened after an automatic recovery attempt.
//

import SwiftUI

struct DataRecoveryView: View {
    let errorMessage: String
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(L10n.string("recovery.title", locale: Locale(identifier: "en")))
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(L10n.string("recovery.body", locale: Locale(identifier: "en")))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(L10n.string("recovery.reset", locale: Locale(identifier: "en")), action: onReset)
                .font(.title3.weight(.bold))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHint(Text("Clears local EasyDial data and restarts setup"))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 252 / 255, green: 248 / 255, blue: 241 / 255))
    }
}
