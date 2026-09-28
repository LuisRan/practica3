//
//  GestorArchivosApp.swift
//  Gestor de Archivos para iPhone — Práctica 3, Ejercicio 2
//  Desarrollo de aplicaciones móviles nativas · ESCOM-IPN
//

import SwiftUI

@main
struct GestorArchivosApp: App {
    @StateObject private var prefs = PreferencesStore()
    @StateObject private var clipboard = FileClipboard()

    init() {
        FileService.shared.seedSampleContentIfNeeded()
        // Asegura que exista Documents/Inbox para poder explorarla.
        try? FileManager.default.createDirectory(at: SandboxLocation.inbox.url, withIntermediateDirectories: true)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prefs)
                .environmentObject(clipboard)
                .tint(prefs.theme.primary)
                .onOpenURL { url in
                    // Archivos abiertos "en" la app desde otra app (LSSupportsOpeningDocumentsInPlace).
                    _ = try? FileService.shared.importExternal(url, into: SandboxLocation.inbox.url)
                }
        }
    }
}

/// Portapapeles interno para copiar / mover elementos entre carpetas.
final class FileClipboard: ObservableObject {
    enum Operation { case copy, move }

    @Published var operation: Operation?
    @Published var items: [URL] = []

    var isActive: Bool { operation != nil && !items.isEmpty }

    func set(_ op: Operation, _ urls: [URL]) {
        operation = op
        items = urls
    }

    func clear() {
        operation = nil
        items = []
    }

    var description: String {
        let verb = operation == .move ? "Mover" : "Copiar"
        return items.count == 1 ? "\(verb) “\(items[0].lastPathComponent)”" : "\(verb) \(items.count) elementos"
    }
}
