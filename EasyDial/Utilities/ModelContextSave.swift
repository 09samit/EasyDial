//
//  ModelContextSave.swift
//  EasyDial
//
//  Surfaces SwiftData save failures instead of silently discarding them.
//

import SwiftData
import Foundation

enum ModelSaveError: LocalizedError {
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

extension ModelContext {
    /// Persists pending changes; throws on failure (callers show `error.save_failed` to users).
    func saveOrThrow() throws {
        do {
            try save()
        } catch {
            throw ModelSaveError.underlying(error)
        }
    }
}
