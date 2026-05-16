//
//  L10n.swift
//  EasyDial
//
//  Resolves UI copy from bundled Localizable.strings for a specific `Locale`.
//  Requires iOS 17+ (see project `IPHONEOS_DEPLOYMENT_TARGET`).
//

import Foundation

/// Localized strings for UI and VoiceOver, keyed like `home.title`.
@available(iOS 17, *)
enum L10n {
    private static let supportedLanguageCodes: Set<String> = ["en", "ar", "es", "hi"]

    static func string(_ key: String, locale: Locale) -> String {
        let code = resolvedLanguageCode(for: locale)
        let value = localizedString(key: key, languageCode: code)
        if value != key { return value }
        if code != "en" {
            let fallback = localizedString(key: key, languageCode: "en")
            if fallback != key { return fallback }
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    private static func resolvedLanguageCode(for locale: Locale) -> String {
        let fromLocale = locale.language.languageCode?.identifier
            ?? locale.identifier.split(separator: "-").first.map(String.init)
            ?? "en"
        let lower = fromLocale.lowercased()
        if supportedLanguageCodes.contains(lower) { return lower }
        return "en"
    }

    private static func localizedString(key: String, languageCode: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
