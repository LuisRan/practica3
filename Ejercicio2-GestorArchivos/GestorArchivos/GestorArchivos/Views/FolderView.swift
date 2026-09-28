//
//  FolderView.swift
//  Contenido de una carpeta: búsqueda, ordenamiento, crear, copiar, mover, renombrar,
//  eliminar (con confirmación), importar y compartir.
//  Gestos: deslizar para eliminar, mantener presionado (menú contextual),
//  deslizar hacia abajo para actualizar.
//

import SwiftUI

struct FolderView: View {
    let url: URL
    var isExternal: Bool = false

    @EnvironmentObject private var prefs: PreferencesStore
    @EnvironmentObject private var clipboard: FileClipboard

    @State private var items: [FileItem] = []
    @State private var searchText = ""
    @State private var loadError: String?
    @State private var errorMessage: String?

    // Diálogos
    @State private var showNewFolder = false
    @State private var showNewTextFile = false
    @State private var newName = ""
    @State private var renameTarget: FileItem?
    @State private var deleteTarget: FileItem?
    @State private var showImporter = false
    @State private var shareItems: SheetURLs?
    @State private var previewItems: SheetURLs?

    private let service = FileService.shared

    private var filteredItems: [FileItem] {
        let base = searchText.isEmpty ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return prefs.sortOption.sort(base, ascending: prefs.sortAscending)
    }

    var body: some View {
        List {
            Section {
                PathBar(url: url)
            }

            if let loadError {
                ContentUnavailableView("No se puede leer la carpeta",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(loadError))
            } else if filteredItems.isEmpty {
                ContentUnavailableView(searchText.isEmpty ? "Carpeta vacía" : "Sin resultados",
                                       systemImage: searchText.isEmpty ? "folder" : "magnifyingglass",
                                       description: Text(searchText.isEmpty
                                                         ? "Crea una carpeta o importa archivos con el botón +."
                                                         : "No hay elementos que coincidan con “\(searchText)”."))
            } else {
                Section {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item.isDirectory ? Route.folder(item.url, external: isExternal)
                                                               : Route.file(item.url)) {
                            FileRowView(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isExternal {
                                Button(role: .destructive) {
                                    deleteTarget = item
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !isExternal {
                                Button {
                                    prefs.toggleFavorite(item.url)
                                } label: {
                                    Label("Favorito", systemImage: prefs.isFavorite(item.url) ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                        }
                        .contextMenu { contextMenu(for: item) }
                    }
                } header: {
                    Text("\(filteredItems.count) elementos · ordenado por \(prefs.sortOption.title.lowercased())")
                }
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Buscar en esta carpeta")
        .refreshable { load() }
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { clipboardBar }
        .onAppear {
            if !isExternal { prefs.lastFolder = url }
            load()
        }
        .onChange(of: prefs.showHiddenFiles) { load() }
        // Nueva carpeta
        .alert("Nueva carpeta", isPresented: $showNewFolder) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") { perform { _ = try service.createFolder(named: newName, in: url) } }
        }
        // Nuevo archivo de texto
        .alert("Nuevo archivo de texto", isPresented: $showNewTextFile) {
            TextField("nombre.txt", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") {
                var name = newName.trimmingCharacters(in: .whitespaces)
                if !name.contains(".") { name += ".txt" }
                perform { _ = try service.createTextFile(named: name, contents: "", in: url) }
            }
        }
        // Renombrar
        .alert("Renombrar", isPresented: Binding(get: { renameTarget != nil },
                                                 set: { if !$0 { renameTarget = nil } })) {
            TextField("Nuevo nombre", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Renombrar") {
                guard let target = renameTarget else { return }
                perform {
                    let newURL = try service.rename(target.url, to: newName)
                    prefs.itemMoved(from: target.url, to: newURL)
                }
            }
        }
        // Confirmación de eliminación
        .confirmationDialog("¿Eliminar “\(deleteTarget?.name ?? "")”?",
                            isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                guard let target = deleteTarget else { return }
                perform {
                    try service.delete(target.url)
                    prefs.itemDeleted(target.url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(deleteTarget?.isDirectory == true
                 ? "Se eliminará la carpeta y todo su contenido. Esta acción no se puede deshacer."
                 : "Esta acción no se puede deshacer.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showImporter) {
            DocumentPicker(mode: .importFiles) { urls in
                var failed: [String] = []
                for picked in urls {
                    do { try service.importExternal(picked, into: url) }
                    catch { failed.append(picked.lastPathComponent) }
                }
                if !failed.isEmpty { errorMessage = "No se pudieron importar: \(failed.joined(separator: ", "))" }
                load()
            }
            .ignoresSafeArea()
        }
        .sheet(item: $shareItems) { share in
            ShareSheet(items: share.urls)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $previewItems) { preview in
            QuickLookPreview(urls: preview.urls)
                .ignoresSafeArea()
        }
    }

    // MARK: - Menú contextual (mantener presionado)

    @ViewBuilder
    private func contextMenu(for item: FileItem) -> some View {
        if !item.isDirectory && QuickLookPreview.canPreview(item.url) {
            Button { previewItems = SheetURLs(urls: [item.url]) } label: {
                Label("Vista rápida", systemImage: "eye")
            }
        }
        Button { shareItems = SheetURLs(urls: [item.url]) } label: {
            Label("Compartir / Exportar", systemImage: "square.and.arrow.up")
        }
        if !isExternal {
            Button { prefs.toggleFavorite(item.url) } label: {
                Label(prefs.isFavorite(item.url) ? "Quitar de favoritos" : "Agregar a favoritos",
                      systemImage: prefs.isFavorite(item.url) ? "star.slash" : "star")
            }
            Divider()
            Button {
                newName = item.name
                renameTarget = item
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            Button { perform { _ = try service.copy(item.url, to: url) } } label: {
                Label("Duplicar", systemImage: "plus.square.on.square")
            }
            Button { clipboard.set(.copy, [item.url]) } label: {
                Label("Copiar…", systemImage: "doc.on.doc")
            }
            Button { clipboard.set(.move, [item.url]) } label: {
                Label("Mover…", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) { deleteTarget = item } label: {
                Label("Eliminar", systemImage: "trash")
            }
        } else {
            Button {
                perform { _ = try service.importExternal(item.url, into: FileService.documentsURL) }
            } label: {
                Label("Importar a Documentos", systemImage: "square.and.arrow.down")
            }
        }
    }

    // MARK: - Barra de herramientas

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Ordenar por", selection: $prefs.sortOption) {
                    ForEach(SortOption.allCases) { opt in
                        Label(opt.title, systemImage: opt.icon).tag(opt)
                    }
                }
                Toggle(isOn: $prefs.sortAscending) {
                    Label("Ascendente", systemImage: "arrow.up")
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
            }
            .accessibilityLabel("Ordenar")
        }
        if !isExternal {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newName = ""
                        showNewFolder = true
                    } label: {
                        Label("Nueva carpeta", systemImage: "folder.badge.plus")
                    }
                    Button {
                        newName = ""
                        showNewTextFile = true
                    } label: {
                        Label("Nuevo archivo de texto", systemImage: "doc.badge.plus")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Importar desde Archivos / iCloud", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Agregar")
            }
        }
    }

    // MARK: - Barra de pegado (copiar / mover)

    @ViewBuilder
    private var clipboardBar: some View {
        if clipboard.isActive && !isExternal {
            HStack {
                Image(systemName: clipboard.operation == .move ? "folder" : "doc.on.doc")
                Text(clipboard.description)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Button("Cancelar") { clipboard.clear() }
                    .buttonStyle(.bordered)
                Button("Pegar aquí") { paste() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.bar)
            .transition(.move(edge: .bottom))
        }
    }

    // MARK: - Acciones

    private func load() {
        do {
            items = try service.contents(of: url, showHidden: prefs.showHiddenFiles)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            items = []
        }
    }

    private func paste() {
        let op = clipboard.operation
        perform {
            for source in clipboard.items {
                if op == .move {
                    let newURL = try service.move(source, to: url)
                    prefs.itemMoved(from: source, to: newURL)
                } else {
                    try service.copy(source, to: url)
                }
            }
        }
        clipboard.clear()
    }

    /// Ejecuta una operación, muestra el error si falla y recarga el listado.
    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
        withAnimation { load() }
    }
}

/// Muestra en todo momento la ruta de la carpeta actual (breadcrumb).
struct PathBar: View {
    let url: URL
    @EnvironmentObject private var prefs: PreferencesStore

    var body: some View {
        let components = FileService.shared.displayPath(for: url)
            .split(separator: "/").map(String.init)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Image(systemName: "iphone")
                ForEach(Array(components.enumerated()), id: \.offset) { index, comp in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(comp)
                        .fontWeight(index == components.count - 1 ? .semibold : .regular)
                        .foregroundStyle(index == components.count - 1 ? prefs.theme.primary : .secondary)
                }
            }
            .font(.footnote)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ruta: \(components.joined(separator: " / "))")
    }
}
