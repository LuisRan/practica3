//
//  RootView.swift
//  Pantalla principal: ubicaciones del sandbox, carpetas externas, favoritos y recientes.
//  Usa NavigationStack con una ruta tipada para la navegación jerárquica.
//

import SwiftUI

enum Route: Hashable {
    case folder(URL, external: Bool)
    case file(URL)
}

struct RootView: View {
    @EnvironmentObject private var prefs: PreferencesStore
    @State private var path: [Route] = []
    @State private var showSettings = false
    @State private var showFolderPicker = false
    @State private var errorMessage: String?
    @State private var restored = false
    /// URLs externas con acceso security-scoped activo durante la sesión.
    @State private var activeExternal: Set<URL> = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                header

                Section("Ubicaciones del sandbox") {
                    ForEach(SandboxLocation.allCases) { loc in
                        NavigationLink(value: Route.folder(loc.url, external: false)) {
                            Label(loc.title, systemImage: loc.icon)
                        }
                    }
                }

                Section {
                    ForEach(prefs.externalLocations) { loc in
                        Button {
                            openExternal(loc)
                        } label: {
                            Label(loc.name, systemImage: "externaldrive.connected.to.line.below")
                                .foregroundStyle(.primary)
                        }
                        .swipeActions {
                            Button("Quitar", role: .destructive) { prefs.removeExternal(loc) }
                        }
                    }
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("Agregar carpeta de Archivos / iCloud", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Carpetas externas")
                } footer: {
                    Text("El acceso se conserva con security-scoped bookmarks. Las carpetas externas se muestran en modo lectura; usa “Importar” para copiar archivos al sandbox.")
                }

                if !prefs.favorites.isEmpty {
                    Section("Favoritos") {
                        ForEach(prefs.favorites, id: \.self) { url in
                            NavigationLink(value: route(for: url)) {
                                FileRowView(item: FileItem(url: url), showPath: true)
                            }
                            .swipeActions {
                                Button("Quitar", systemImage: "star.slash") { prefs.toggleFavorite(url) }
                                    .tint(.orange)
                            }
                        }
                    }
                }

                if !prefs.recents.isEmpty {
                    Section {
                        ForEach(prefs.recents.prefix(10), id: \.self) { url in
                            NavigationLink(value: route(for: url)) {
                                FileRowView(item: FileItem(url: url), showPath: true)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Recientes")
                            Spacer()
                            Button("Borrar") { prefs.clearRecents() }
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Archivos")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .folder(let url, let external):
                    FolderView(url: url, isExternal: external)
                case .file(let url):
                    FileDetailView(url: url)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showFolderPicker) {
                DocumentPicker(mode: .openFolder) { urls in
                    guard let url = urls.first else { return }
                    do { try prefs.addExternalFolder(url) }
                    catch { errorMessage = error.localizedDescription }
                }
                .ignoresSafeArea()
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear(perform: restoreLastFolder)
    }

    private var header: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gestor de Archivos")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Tema \(prefs.theme.nombre) · ESCOM-IPN")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowBackground(prefs.theme.headerGradient)
        }
    }

    private func route(for url: URL) -> Route {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue ? .folder(url, external: false) : .file(url)
    }

    private func openExternal(_ loc: ExternalLocation) {
        do {
            let url = try prefs.resolve(loc)
            if !activeExternal.contains(url) {
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "iOS ya no concede acceso a “\(loc.name)”. Vuelve a agregar la carpeta."
                    return
                }
                activeExternal.insert(url)
            }
            path.append(.folder(url, external: true))
        } catch {
            errorMessage = "No se pudo abrir la carpeta externa: \(error.localizedDescription)"
        }
    }

    /// Restaura la última carpeta visitada reconstruyendo la jerarquía desde su raíz.
    private func restoreLastFolder() {
        guard !restored else { return }
        restored = true
        guard let last = prefs.lastFolder else { return }
        let roots = SandboxLocation.allCases.map { $0.url.standardizedFileURL.resolvingSymlinksInPath() }
        let target = last.standardizedFileURL.resolvingSymlinksInPath()
        // Busca la raíz más específica que contenga la carpeta.
        guard let root = roots.filter({ target.path.hasPrefix($0.path) })
                .max(by: { $0.path.count < $1.path.count }) else { return }
        var chain: [Route] = [.folder(root, external: false)]
        let relative = target.path.dropFirst(root.path.count).split(separator: "/")
        var current = root
        for component in relative {
            current = current.appendingPathComponent(String(component), isDirectory: true)
            chain.append(.folder(current, external: false))
        }
        path = chain
    }
}
