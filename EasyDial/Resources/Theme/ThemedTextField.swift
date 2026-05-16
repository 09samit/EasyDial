//
//  ThemedTextField.swift
//  EasyDial
//
//  Text field with theme-colored placeholder prompt and entered text.
//

import SwiftUI

struct ThemedTextField: View {
    let prompt: String
    @Binding var text: String
    let colors: ThemeColors
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(prompt).foregroundStyle(colors.placeholderText)
        )
        .foregroundStyle(colors.primaryText)
        .keyboardType(keyboardType)
    }
}
