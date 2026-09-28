//
//  GalleryView.swift
//  Galería integrada: fotos (cuadrícula con miniaturas en caché) y audios,
//  filtros por tipo, álbum y etiqueta; importación y exportación.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

enum MediaFilter: String, CaseIterable, Identifiable {
    case all, photos, audio
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Todo"
        case .photos: return "Fotos"
        case .audio: return "Audio"
        }
    }
}

struct GalleryView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appTheme) private var theme

    @FetchRequest(entity: PersistenceController.albumEntity,
                  sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var albums: FetchedResults<Album>

    @State private var filter: MediaFilter = .all
    @State private var album: Album?
    @State private var search = ""
    @State private var showAlbums = false
    @State private var showPhotoImport = false
    @State private var showAudioImport = false
    @State private var share: ShareItems?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            MediaGrid(filter: filter, album: album, search: search, share: $share)
                .navigationTitle(album?.name ?? "Galería")
                .searchable(text: $search, prompt: "Buscar por etiqueta o nombre")
                .safeAreaInset(edge: .top) {
                    Picker("Tipo", selection: $filter) {
                        ForEach(MediaFilter.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    .background(.bar)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Álbum", selection: $album) {
                                Text("Todos los álbumes").tag(Album?.none)
                                ForEach(albums) { a in
                                    Text("\(a.name) (\(a.items.count))").tag(Optional(a))
                                }
                            }
                            Divider()
                            Button { showAlbums = true } label: {
                                Label("Administrar álbumes…", systemImage: "rectangle.stack.badge.plus")
                            }
                        } label: {
                            Image(systemName: "rectangle.stack")
                        }
                        .accessibilityLabel("Álbumes")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { showPhotoImport = true } label: {
                                Label("Importar fotos (fototeca)", systemImage: "photo.badge.plus")
                            }
                            Button { showAudioImport = true } label: {
                                Label("Importar audio (Archivos)", systemImage: "waveform.badge.plus")
                            }
                            Divider()
                            Button { exportAll() } label: {
                                Label("Exportar contenido visible…", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showAlbums) { AlbumsView() }
                .sheet(isPresented: $showPhotoImport) {
                    PhotoLibraryPicker { datas in
                        showPhotoImport = false
                        for data in datas {
                            do {
                                let item = try MediaStore.savePhoto(data, filter: nil, location: nil, album: album, context: context)
                                item.tags = "importado"
                                context.saveIfNeeded()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .ignoresSafeArea()
                }
                .fileImporter(isPresented: $showAudioImport, allowedContentTypes: [.audio],
                              allowsMultipleSelection: true) { result in
                    switch result {
                    case .success(let urls):
                        for url in urls {
                            do {
                                let item = try MediaStore.importAudio(from: url, context: context)
                                item.album = album
                                context.saveIfNeeded()
                            } catch {
                                errorMessage = "No se pudo importar \(url.lastPathComponent): \(error.localizedDescription)"
                            }
                        }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .sheet(item: $share) { s in
                    ShareSheet(items: s.urls).presentationDetents([.medium, .large])
                }
                .alert("Galería", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                    Button("Aceptar", role: .cancel) {}
                } message: { Text(errorMessage ?? "") }
        }
    }

    private func exportAll() {
        let request = NSFetchRequest<MediaItem>(entityName: "MediaItem")
        request.predicate = MediaGrid.predicate(filter: filter, album: album, search: search)
        let items = (try? context.fetch(request)) ?? []
        let urls = items.map(\.fileURL).filter { FileManager.default.fileExists(atPath: $0.path) }
        if urls.isEmpty { errorMessage = "No hay elementos para exportar." } else { share = ShareItems(urls: urls) }
    }
}

/// Cuadrícula/lista con FetchRequest dinámico según los filtros.
struct MediaGrid: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.appTheme) private var theme
    @FetchRequest private var items: FetchedResults<MediaItem>
    @Binding var share: ShareItems?

    @State private var playing: MediaItem?
    @State private var tagEditing: MediaItem?
    @State private var toDelete: MediaItem?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 3)]

    init(filter: MediaFilter, album: Album?, search: String, share: Binding<ShareItems?>) {
        _items = FetchRequest(entity: PersistenceController.mediaEntity,
                              sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
                              predicate: Self.predicate(filter: filter, album: album, search: search),
                              animation: .default)
        _share = share
    }

    static func predicate(filter: MediaFilter, album: Album?, search: String) -> NSPredicate? {
        var parts: [NSPredicate] = []
        switch filter {
        case .photos: parts.append(NSPredicate(format: "kind == %@", "photo"))
        case .audio: parts.append(NSPredicate(format: "kind == %@", "audio"))
        case .all: break
        }
        if let album { parts.append(NSPredicate(format: "album == %@", album)) }
        let q = search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            parts.append(NSPredicate(format: "tags CONTAINS[cd] %@ OR fileName CONTAINS[cd] %@ OR album.name CONTAINS[cd] %@", q, q, q))
        }
        return parts.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    private var photos: [MediaItem] { items.filter { $0.mediaKind == .photo } }
    private var audios: [MediaItem] { items.filter { $0.mediaKind == .audio } }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                ContentUnavailableView("Sin contenido", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Toma fotos o graba audio; aparecerán aquí."))
                    .padding(.top, 80)
            }
            if !photos.isEmpty {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(photos) { item in
                        NavigationLink {
                            PhotoPagerView(photos: photos, selection: item.objectID)
                        } label: {
                            PhotoThumb(item: item)
                        }
                        .contextMenu { menu(for: item) }
                    }
                }
                .padding(.horizontal, 3)
            }
            if !audios.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Grabaciones")
                        .font(.headline)
                        .padding()
                    ForEach(audios) { item in
                        Button { playing = item } label: {
                            AudioRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(for: item) }
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }
        .sheet(item: $playing) { item in
            AudioPlayerView(item: item).presentationDetents([.medium, .large])
        }
        .sheet(item: $tagEditing) { item in
            MetadataEditor(item: item)
        }
        .confirmationDialog("¿Eliminar este elemento?",
                            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let item = toDelete { withAnimation { MediaStore.delete(item, context: context) } }
            }
        } message: { Text("Se borrará el archivo del dispositivo.") }
    }

    @ViewBuilder
    private func menu(for item: MediaItem) -> some View {
        Button { share = ShareItems(urls: [item.fileURL]) } label: {
            Label("Compartir / Exportar", systemImage: "square.and.arrow.up")
        }
        Button { tagEditing = item } label: {
            Label("Etiquetas y álbum", systemImage: "tag")
        }
        Button(role: .destructive) { toDelete = item } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }
}

struct PhotoThumb: View {
    let item: MediaItem
    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 3) {
                    if item.hasLocation { Image(systemName: "location.fill") }
                    if item.filterName != nil { Image(systemName: "camera.filters") }
                }
                .font(.caption2)
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .padding(4)
            }
            .task(id: item.objectID) {
                if let cached = ThumbnailStore.shared.cached(for: item) {
                    image = cached
                } else {
                    // Se genera con ImageIO (submuestreo) y se guarda en disco + memoria.
                    image = ThumbnailStore.shared.thumbnail(for: item)
                }
            }
            .accessibilityLabel("Foto del \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
    }
}

struct AudioRow: View {
    let item: MediaItem
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text("· \(item.duration.mmss)")
                    if let a = item.album { Text("· \(a.name)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !item.tagList.isEmpty {
                    Text(item.tagList.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(theme.primary)
                }
            }
            Spacer()
            Image(systemName: "play.fill").foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
