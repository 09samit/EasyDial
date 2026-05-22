//
//  EasyDialApp.swift
//  EasyDial
//
//  Core Data stack, AppStore, and global services. Minimum iOS version: 17.0.
//

import SwiftUI

@available(iOS 17, *)
@main
struct EasyDialApp: App {
    private let services = AppServices()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var store: AppStore

    init() {
        let controller = PersistenceController.shared
        let s = AppStore(
            contactRepo: CoreDataFavoriteContactRepository(
                context: controller.container.viewContext
            ),
            prefsRepo: CoreDataAppPreferencesRepository(
                context: controller.container.viewContext
            ),
            photoStorage: FileSystemContactPhotoStorage()
        )
        _store = StateObject(wrappedValue: s)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isReady {
                    RootView()
                        .environment(\.appServices, services)
                        .environmentObject(themeManager)
                        .environmentObject(store)
                } else if let error = store.loadError {
                    DataRecoveryView(
                        errorMessage: error,
                        onReset: { store.hardReset() }
                    )
                } else {
                    Color(red: 252 / 255, green: 248 / 255, blue: 241 / 255)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView(
                                L10n.string("common.loading", locale: Locale(identifier: "en"))
                            )
                        }
                }
            }
            .task {
                store.bootstrap()
                themeManager.attach(store: store)
            }
        }
    }
}
