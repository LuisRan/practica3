//
//  CamaraMicApp.swift
//  Cámara y Micrófono para iPhone — Práctica 3, Ejercicio 3
//  Desarrollo de aplicaciones móviles nativas · ESCOM-IPN
//

import SwiftUI

@main
struct CamaraMicApp: App {
    let persistence = PersistenceController.shared
    @AppStorage("theme") private var themeRaw = AppTheme.guinda.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .tint((AppTheme(rawValue: themeRaw) ?? .guinda).primary)
        }
    }
}

struct ContentView: View {
    @AppStorage("theme") private var themeRaw = AppTheme.guinda.rawValue
    @State private var tab = 0

    var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .guinda }

    var body: some View {
        TabView(selection: $tab) {
            CameraView()
                .tabItem { Label("Cámara", systemImage: "camera.fill") }
                .tag(0)
            AudioRecorderView()
                .tabItem { Label("Audio", systemImage: "mic.fill") }
                .tag(1)
            GalleryView()
                .tabItem { Label("Galería", systemImage: "photo.stack.fill") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .environment(\.appTheme, theme)
    }
}

// MARK: - Tema en el entorno de SwiftUI

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .guinda
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
