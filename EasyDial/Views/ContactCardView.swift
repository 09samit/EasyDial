//
//  ContactCardView.swift
//  EasyDial
//
//  Grid cell: photo, multiline name, primary Call control. Layout avoids wasted vertical space and
//  supports Dynamic Type (HIG: legible default, minimumScaleFactor only when needed).
//

import SwiftData
import SwiftUI

struct ContactCardView: View {
    let contact: FavoriteContact
    let colors: ThemeColors
    let onCall: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Fixed image height; width follows the card’s inner width (after horizontal insets). iPad uses a taller photo area.
    private var avatarHeight: CGFloat {
        let phoneHeight: CGFloat
        switch dynamicTypeSize {
        case .accessibility3, .accessibility4, .accessibility5: phoneHeight = 88
        case .accessibility1, .accessibility2: phoneHeight = 96
        default: phoneHeight = 100
        }
        return isPad ? phoneHeight + 20 : phoneHeight
    }

    private var cardMinHeight: CGFloat { isPad ? 232 : 212 }
    private var cardMaxHeight: CGFloat { isPad ? 268 : 248 }

    private let avatarCornerRadius: CGFloat = 12
    private let cardCornerRadius: CGFloat = 16
    private let imageEdgeInset: CGFloat = 8
    private let imageToNameSpacing: CGFloat = 10

    var body: some View {
        Button(action: onCall) {
            VStack(alignment: .leading, spacing: 0) {
                avatar
                    .padding(.top, imageEdgeInset)
                    .frame(maxWidth: .infinity)

                Text(contact.displayName)
                    .font(colors.accessibilityEmphasis ? .title2.weight(.heavy) : .title3.weight(.bold))
                    .foregroundStyle(colors.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .padding(.top, imageToNameSpacing)

                Spacer(minLength: 4)

                callAffordance
            }
            .padding(.horizontal, imageEdgeInset)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, minHeight: cardMinHeight, maxHeight: cardMaxHeight, alignment: .topLeading)
            .background(colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(colors.divider, lineWidth: colors.cardStrokeWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .shadow(
                color: colors.accessibilityEmphasis ? .clear : Color.black.opacity(0.06),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(Text(L10n.string("a11y.call_hint", locale: locale)))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabelText: Text {
        let format = L10n.string("a11y.call_contact", locale: locale)
        let message = String(format: format, locale: locale, arguments: [contact.displayName])
        return Text(message)
    }

    private var initialsFontSize: CGFloat {
        let phoneSize: CGFloat = dynamicTypeSize >= .accessibility1 ? 36 : 40
        return isPad ? phoneSize + 4 : phoneSize
    }

    private var avatarShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: avatarCornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = contact.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: avatarHeight)
                .clipShape(avatarShape)
                .overlay(avatarShape.stroke(colors.divider, lineWidth: 1))
                .accessibilityHidden(true)
        } else {
            ZStack {
                avatarShape
                    .fill(colors.primaryButton.opacity(0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(initials(from: contact.displayName))
                    .font(.system(size: initialsFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.primaryButton)
            }
            .frame(maxWidth: .infinity, minHeight: avatarHeight, maxHeight: avatarHeight)
            .clipShape(avatarShape)
            .overlay(avatarShape.stroke(colors.divider, lineWidth: 1))
            .accessibilityHidden(true)
        }
    }

    private var callAffordance: some View {
        HStack(spacing: 8) {
            Image(systemName: "phone.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(colors.onPrimaryButton)
                .accessibilityHidden(true)
            Text(L10n.string("contact.call", locale: locale))
                .font(.body.weight(.bold))
                .foregroundStyle(colors.onPrimaryButton)
        }
        .frame(maxWidth: .infinity, minHeight: colors.accessibilityEmphasis ? 50 : 44)
        .padding(.horizontal, 10)
        .background(colors.primaryButton)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        let joined = letters.joined().uppercased()
        return String(joined.prefix(2))
    }
}

#Preview {
    let en = Locale(identifier: "en")
    let contact = FavoriteContact(
        sortOrder: 0,
        displayName: "Priya Sharma",
        relationshipLabel: FavoriteContact.hiddenRelationshipLabel,
        phoneNumber: "5550100"
    )
    ContactCardView(contact: contact, colors: ThemeColors.palette(for: .light), onCall: {})
        .environment(\.locale, en)
        .padding()
        .background(ThemeColors.palette(for: .light).background)
}
