//
//  ContactPhotoStorage.swift
//  EasyDial
//
//  Protocol and implementations for contact photo file storage.
//  Production: files in App Group container (widget-accessible).
//  In-memory: for previews and tests.
//

import Foundation
import UIKit

// MARK: - Protocol

protocol ContactPhotoStorage {
    /// Saves (and optimizes) photo data for the given contact ID. Throws on disk-full errors.
    func save(_ data: Data, for id: UUID) throws
    /// Loads photo data; returns nil if no file exists or App Group is unavailable.
    func load(for id: UUID) -> Data?
    /// Silently removes the photo file; no-ops if file doesn't exist.
    func delete(for id: UUID)
    /// Removes every file in the ContactPhotos directory.
    func deleteAll()
    /// Deletes files whose UUIDs are absent from validIDs — cleans up after crash-interrupted saves.
    func cleanupOrphanedFiles(validIDs: Set<UUID>)
}

// MARK: - PhotoUpdate

/// Describes the desired photo change when updating a favorite contact.
enum PhotoUpdate {
    case unchanged          // Photo is already on disk; don't touch it.
    case set(Data)          // Write this new data (will be optimized before writing).
    case remove             // Delete the photo file.
}

// MARK: - FileSystem Implementation

final class FileSystemContactPhotoStorage: ContactPhotoStorage {
    /// The directory where contact photos are written.
    /// Preference order:
    ///   1. App Group container  → widget can read these files
    ///   2. Application Support  → fallback when App Group entitlement is not yet configured
    let directory: URL

    init(appGroupID: String = "group.com.hexa.easydial") {
        let fm = FileManager.default
        let base =
            fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        let dir = base.appendingPathComponent("ContactPhotos", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        directory = dir
    }

    func save(_ data: Data, for id: UUID) throws {
        let url = fileURL(for: id)
        // Optimize to a compact JPEG thumbnail; fall back to raw bytes if the
        // input can't be decoded (e.g. corrupt or unsupported format).
        let payload = ImageDataOptimizer.thumbnailJPEG(from: data) ?? data
        try payload.write(to: url, options: .atomic)
    }

    func load(for id: UUID) -> Data? {
        try? Data(contentsOf: fileURL(for: id))
    }

    func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    func deleteAll() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    func cleanupOrphanedFiles(validIDs: Set<UUID>) {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            if let uuid = UUID(uuidString: name), !validIDs.contains(uuid) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).jpg")
    }
}

// MARK: - InMemory Implementation

final class InMemoryContactPhotoStorage: ContactPhotoStorage {
    private var store: [UUID: Data] = [:]

    func save(_ data: Data, for id: UUID) throws { store[id] = data }
    func load(for id: UUID) -> Data? { store[id] }
    func delete(for id: UUID) { store.removeValue(forKey: id) }
    func deleteAll() { store.removeAll() }
    func cleanupOrphanedFiles(validIDs: Set<UUID>) {}
}
