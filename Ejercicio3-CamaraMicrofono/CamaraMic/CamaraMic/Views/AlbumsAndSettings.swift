//
//  AlbumsAndSettings.swift
//  - AlbumsView: crear, renombrar y eliminar álbumes (Core Data).
//  - SettingsView: tema, ubicación, uso de almacenamiento y caché.
//

import SwiftUI
import CoreData

struct AlbumsView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(entity: PersistenceController.albumEntity,
                  sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var albums: FetchedResults<Album>

    @State private var newName = ""
    @State private var showNew = false
    @State private var renaming: Album?

    var body: some View {
        NavigationStack {
            List {
                if albums.isEmpty {
                    ContentUnavailableView("Sin álbumes", systemImage: "rectangle.stack",
                                           description: Text("Crea álbumes para organizar fotos y audios."))
                }
                ForEach(albums) { album in
                    HStack {
                        Image(systemName: "rectangle.stack.fill")
                        Text(album.name)
                        Spacer()
                        Text("\(album.items.count)").foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Renombrar") { newName = album.name; renaming = album }.tint(.orange)
                    }
                }
                .onDelete { idx in
                    idx.map { albums[$0] }.forEach { context.delete($0) }
                    context.saveIfNeeded()
                }
            }
            .navigationTitle("Álbumes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { newName = ""; showNew = true } label: { Image(systemName: "plus") }
                }
            }
            .alert("Nuevo álbum", isPresented: $showNew) {
                TextField("Nombre", text: $newName)
                Button("Cancelar", role: .cancel) {}
                Button("Crear") { create() }
            }
            .alert("Renombrar álbum", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Nombre", text: $newName)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { renaming?.name = name; context.saveIfNeeded() }
                }
            }
        }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let album = Album(entity: PersistenceController.albumEntity, insertInto: context)
        album.id = UUID()
        album.name = name
        album.createdAt = Date()
        context.saveIfNeeded()
    }
}

struct SettingsView: View {
    @AppStorage("theme") private var themeRaw = AppTheme.guinda.rawValue
    @AppStorage("saveLocation") private var saveLocation = true
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var scheme
    @State private var usage: Int64 = 0
    @State private var counts = (photos: 0, audio: 0)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tema", selection: $themeRaw) {
                        ForEach(AppTheme.allCases) { t in
                            HStack {
                                Circle().fill(t.primary).frame(width: 14, height: 14)
                                Text(t.nombre)
                            }
                            .tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Apariencia")
                } footer: {
                    Text("El tema se adapta al modo \(scheme == .dark ? "oscuro" : "claro") del sistema automáticamente.")
                }

                Section {
                    Toggle("Guardar ubicación en metadatos", isOn: $saveLocation)
                } footer: {
                    Text("Usa el GPS del dispositivo (no requiere Internet). Si niegas el permiso, las capturas se guardan sin ubicación.")
                }

                Section("Almacenamiento local") {
                    LabeledContent("Fotos", value: "\(counts.photos)")
                    LabeledContent("Grabaciones", value: "\(counts.audio)")
                    LabeledContent("Espacio usado", value: ByteCountFormatter.string(fromByteCount: usage, countStyle: .file))
                    Button("Vaciar caché de miniaturas") {
                        ThumbnailStore.shared.clearAll()
                    }
                }

                Section("Permisos") {
                    Text("Cámara: NSCameraUsageDescription\nMicrófono: NSMicrophoneUsageDescription\nUbicación: NSLocationWhenInUseUsageDescription")
                        .font(.caption.monospaced())
                    Button("Abrir Ajustes de la app") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }

                Section("Acerca de") {
                    LabeledContent("Práctica", value: "3 · Ejercicio 3")
                    LabeledContent("Escuela", value: "ESCOM - IPN")
                }
            }
            .navigationTitle("Ajustes")
            .onAppear(perform: refresh)
        }
    }

    private func refresh() {
        usage = MediaStore.totalSize()
        let p = NSFetchRequest<MediaItem>(entityName: "MediaItem")
        p.predicate = NSPredicate(format: "kind == %@", "photo")
        let a = NSFetchRequest<MediaItem>(entityName: "MediaItem")
        a.predicate = NSPredicate(format: "kind == %@", "audio")
        counts = ((try? context.count(for: p)) ?? 0, (try? context.count(for: a)) ?? 0)
    }
}
