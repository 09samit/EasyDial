//
//  EasyDialApp.swift
//  EasyDial
//
//  SwiftData container + global services. Minimum iOS version: 17.0 (`IPHONEOS_DEPLOYMENT_TARGET`).
//

import SwiftData
import SwiftUI

@available(iOS 17, *)
@MainActor
final class AppLaunchState: ObservableObject {
    @Published private(set) var container: ModelContainer?
    @Published private(set) var loadError: String?
    @Published private(set) var isLoading = true

    func bootstrap() {
        guard container == nil, isLoading else { return }
        do {
            container = try ModelContainerFactory.makePersistentContainer()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func resetPersistentDataAndReload() {
        ModelContainerFactory.destroyPersistentStoreFiles()
        ModelContainerFactory.clearRecoveryAttemptFlag()
        container = nil
        loadError = nil
        isLoading = true
        bootstrap()
    }
}

@available(iOS 17, *)
@main
struct EasyDialApp: App {
    private let services = AppServices()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var launchState = AppLaunchState()

    var body: some Scene {
        WindowGroup {
            Group {
                if launchState.isLoading {
                    ProgressView(L10n.string("common.loading", locale: Locale(identifier: "en")))
                } else if let container = launchState.container {
                    RootView()
                        .environment(\.appServices, services)
                        .environmentObject(themeManager)
                        .modelContainer(container)
                } else {
                    DataRecoveryView(
                        errorMessage: launchState.loadError ?? "",
                        onReset: { launchState.resetPersistentDataAndReload() }
                    )
                }
            }
            .task { launchState.bootstrap() }
        }
    }
}
