//
//  CallService.swift
//  EasyDial
//
//  Places telephone calls via system URL scheme with human-readable failures.
//

import UIKit

final class CallService {
    /// Sanitize and dial. Throws only for programmer-facing cases; prefer returning Bool for UX simplicity.
    func placeCall(to rawNumber: String) throws {
        let sanitized = Self.sanitizePhone(rawNumber)
        guard !sanitized.isEmpty else { throw CallServiceError.invalidNumber }
        guard let url = URL(string: "tel:\(sanitized)") else { throw CallServiceError.invalidNumber }
        guard UIApplication.shared.canOpenURL(url) else { throw CallServiceError.cannotPlaceCall }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Best-effort dial for tap handlers; surfaces friendly messaging via returned optional error description.
    func placeCallMessageIfFailed(_ rawNumber: String, locale: Locale) -> String? {
        let sanitized = Self.sanitizePhone(rawNumber)
        guard !sanitized.isEmpty else {
            return L10n.string("error.invalid_phone", locale: locale)
        }
        guard let url = URL(string: "tel:\(sanitized)") else {
            return L10n.string("error.invalid_phone", locale: locale)
        }
        guard UIApplication.shared.canOpenURL(url) else {
            return L10n.string("error.cannot_place_call", locale: locale)
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return nil
    }

    static func sanitizePhone(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var result = ""
        let scalars = trimmed.unicodeScalars
        var sawPlus = false
        for (i, s) in scalars.enumerated() {
            if i == 0, s == "+" {
                result.append("+")
                sawPlus = true
                continue
            }
            if CharacterSet.decimalDigits.contains(s) {
                result.unicodeScalars.append(s)
            }
        }
        if sawPlus, result.first == "+" {
            return result
        }
        return result.replacingOccurrences(of: "+", with: "")
    }
}

private enum CallServiceError: Error {
    case invalidNumber
    case cannotPlaceCall
}
