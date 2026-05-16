//
//  AppLanguage.swift
//  EasyDial
//
//  Supported app languages (UI + AVSpeech): English, Arabic, Spanish, Hindi only.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case arabic = "ar"
    case spanish = "es"
    case hindi = "hi"

    var id: String { rawValue }

    /// Shown in the language picker (native script).
    var nativeTitle: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        case .spanish: return "Español"
        case .hindi: return "हिन्दी"
        }
    }

    /// Maps legacy stored codes from older builds to a supported language.
    static func resolved(from code: String) -> AppLanguage {
        AppLanguage(rawValue: code) ?? .english
    }
}
