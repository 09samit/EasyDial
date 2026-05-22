//
//  PreviewSampleData.swift
//  EasyDial
//
//  In-memory AppStore with sample data for SwiftUI previews (not shipped to users).
//

import Foundation

@MainActor
enum PreviewSampleData {
    /// A fully bootstrapped AppStore backed by in-memory repositories and photo storage.
    static var store: AppStore { AppStore.preview }
}
