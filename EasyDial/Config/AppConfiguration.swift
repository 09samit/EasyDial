//
//  AppConfiguration.swift
//  EasyDial
//
//  Reads non-user-facing limits and feature flags from `AppConfiguration.plist` in the app bundle.
//

import Foundation

/// Values from `Resources/AppConfiguration.plist`. Edit that file to change behavior without code changes.
enum AppConfiguration {
    private static let plistName = "AppConfiguration"

    static let shared: Values = load()

    struct Values: Sendable {
        /// Maximum favorites the user can select during first-run setup.
        let maxFavoriteContactsDuringSetup: Int
        /// Maximum favorite contacts allowed in the app overall (setup + Settings).
        let maxTotalFavoriteContacts: Int
    }

    private static func load() -> Values {
        guard let url = Bundle.main.url(forResource: plistName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            return Values(
                maxFavoriteContactsDuringSetup: 5,
                maxTotalFavoriteContacts: 20
            )
        }

        let setupMax = positiveInt(dict["MaxFavoriteContactsDuringSetup"], default: 5)
        let totalMax = positiveInt(dict["MaxTotalFavoriteContacts"], default: 20)
        let cappedSetup = min(setupMax, totalMax)

        return Values(
            maxFavoriteContactsDuringSetup: cappedSetup,
            maxTotalFavoriteContacts: max(1, totalMax)
        )
    }

    private static func positiveInt(_ any: Any?, default def: Int) -> Int {
        if let n = any as? Int { return max(1, n) }
        if let n = any as? NSNumber { return max(1, n.intValue) }
        return max(1, def)
    }
}
