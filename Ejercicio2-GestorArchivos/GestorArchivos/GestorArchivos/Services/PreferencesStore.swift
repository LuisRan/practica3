//
//  PreferencesStore.swift
//  Persistencia local con UserDefaults:
//   - Tema seleccionado, criterio de ordenamiento y última carpeta visitada.
//   - Historial de archivos recientes.
//   - Favoritos.
//   - Security-scoped bookmarks de carpetas externas (UIDocumentPicker).
//
//  Las rutas se guardan RELATIVAS al contenedor de la app, porque la ruta absoluta
//  del sandbox cambia entre instalaciones/actualizaciones en iOS.
//

import Foundation
import SwiftUI

struct ExternalLocation: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var bookmark: Data
}

final class PreferencesStore: ObservableObject {
    private let defaults: UserDefaults
    private let maxRecents = 30

    @Published var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published var sortOption: SortOption {
        didSet { defaults.set(sortOption.rawValue, forKey: Keys.sort) }
    }
    @Published var sortAscending: Bool {
        didSet { defaults.set(sortAscending, forKey: Keys.ascending) }
    }
    @Published var showHiddenFiles: Bool {
        didSet { defaults.set(showHiddenFiles, forKey: Keys.hidden) }
    }
    @Published private(set) var recentPaths: [String]
    @Published private(set) var favoritePaths: [String]
    @Published private(set) var externalLocations: [ExternalLocation]

    private enum Keys {
        static let theme = "pref.theme"
        static let sort = "pref.sort"
        static let ascending = "pref.ascending"
        static let hidden = "pref.hidden"
        static let lastFolder = "pref.lastFolder"
        static let recents = "pref.recents"
        static let favorites = "pref.favorites"
        static let external = "pref.external"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .guinda
        sortOption = SortOption(rawValue: defaults.string(forKey: Keys.sort) ?? "") ?? .name
        sortAscending = defaults.object(forKey: Keys.ascending) as? Bool ?? true
        showHiddenFiles = defaults.bool(forKey: Keys.hidden)
        recentPaths = defaults.stringArray(forKey: Keys.recents) ?? []
        favoritePaths = defaults.stringArray(forKey: Keys.favorites) ?? []
        if let data = defaults.data(forKey: Keys.external),
           let list = try? JSONDecoder().decode([ExternalLocation].self, from: data) {
            externalLocations = list
        } else {
            externalLocations = []
        }
    }

    // MARK: - Conversión ruta relativa <-> URL

    private func relative(_ url: URL) -> String {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let root = FileService.containerURL.resolvingSymlinksInPath().path
        return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : path
    }

    private func absolute(_ relative: String) -> URL {
        if relative.hasPrefix("/private") || !relative.hasPrefix("/") {
            return URL(fileURLWithPath: relative)
        }
        return FileService.containerURL.appendingPathComponent(String(relative.dropFirst()))
    }

    // MARK: - Última carpeta

    var lastFolder: URL? {
        get {
            guard let rel = defaults.string(forKey: Keys.lastFolder) else { return nil }
            let url = absolute(rel)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        set {
            if let newValue { defaults.set(relative(newValue), forKey: Keys.lastFolder) }
            else { defaults.removeObject(forKey: Keys.lastFolder) }
        }
    }

    // MARK: - Recientes

    var recents: [URL] {
        recentPaths.map(absolute).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func addRecent(_ url: URL) {
        let rel = relative(url)
        var list = recentPaths.filter { $0 != rel }
        list.insert(rel, at: 0)
        if list.count > maxRecents { list = Array(list.prefix(maxRecents)) }
        recentPaths = list
        defaults.set(list, forKey: Keys.recents)
    }

    func clearRecents() {
        recentPaths = []
        defaults.set([String](), forKey: Keys.recents)
    }

    // MARK: - Favoritos

    var favorites: [URL] {
        favoritePaths.map(absolute).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func isFavorite(_ url: URL) -> Bool { favoritePaths.contains(relative(url)) }

    func toggleFavorite(_ url: URL) {
        let rel = relative(url)
        if let idx = favoritePaths.firstIndex(of: rel) {
            favoritePaths.remove(at: idx)
        } else {
            favoritePaths.append(rel)
        }
        defaults.set(favoritePaths, forKey: Keys.favorites)
    }

    /// Actualiza referencias cuando un archivo se renombra o se mueve.
    func itemMoved(from old: URL, to new: URL) {
        let o = relative(old), n = relative(new)
        func fix(_ p: String) -> String {
            if p == o { return n }
            if p.hasPrefix(o + "/") { return n + p.dropFirst(o.count) }
            return p
        }
        favoritePaths = favoritePaths.map(fix)
        recentPaths = recentPaths.map(fix)
        defaults.set(favoritePaths, forKey: Keys.favorites)
        defaults.set(recentPaths, forKey: Keys.recents)
    }

    func itemDeleted(_ url: URL) {
        let o = relative(url)
        favoritePaths.removeAll { $0 == o || $0.hasPrefix(o + "/") }
        recentPaths.removeAll { $0 == o || $0.hasPrefix(o + "/") }
        defaults.set(favoritePaths, forKey: Keys.favorites)
        defaults.set(recentPaths, forKey: Keys.recents)
    }

    // MARK: - Carpetas externas (security-scoped bookmarks)

    func addExternalFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let location = ExternalLocation(id: UUID(), name: url.lastPathComponent, bookmark: data)
        externalLocations.append(location)
        saveExternal()
    }

    func removeExternal(_ location: ExternalLocation) {
        externalLocations.removeAll { $0.id == location.id }
        saveExternal()
    }

    /// Resuelve el bookmark; si está "stale" lo regenera y lo guarda.
    func resolve(_ location: ExternalLocation) throws -> URL {
        var stale = false
        let url = try URL(resolvingBookmarkData: location.bookmark, options: [], relativeTo: nil,
                          bookmarkDataIsStale: &stale)
        if stale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil),
               let idx = externalLocations.firstIndex(where: { $0.id == location.id }) {
                externalLocations[idx].bookmark = fresh
                saveExternal()
            }
        }
        return url
    }

    private func saveExternal() {
        if let data = try? JSONEncoder().encode(externalLocations) {
            defaults.set(data, forKey: Keys.external)
        }
    }
}
