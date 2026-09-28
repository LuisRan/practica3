//
//  PhotoViews.swift
//  - PhotoPagerView: visor deslizable entre fotos con zoom (pinza y doble toque).
//  - PhotoEditorView: edición básica (filtros, brillo, contraste, saturación,
//    rotación y recorte cuadrado) con Core Image.
//  - MetadataEditor: etiquetas, álbum y ubicación (Core Data).
//

import SwiftUI
import CoreData
import MapKit

struct PhotoPagerView: View {
    let photos: [MediaItem]
    @State var selection: NSManagedObjectID
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing: MediaItem?
    @State private var info: MediaItem?
    @State private var share: ShareItems?
    @State private var confirmDelete = false
    @State private var reloadToken = UUID()

    private var current: MediaItem? { photos.first { $0.objectID == selection } }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(photos) { item in
                ZoomableImage(url: item.fileURL)
                    .id("\(item.objectID)-\(reloadToken)")
                    .tag(item.objectID)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(current?.createdAt.formatted(date: .abbreviated, time: .shortened) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { if let c = current { share = ShareItems(urls: [c.fileURL]) } } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Spacer()
                Button { editing = current } label: { Label("Editar", systemImage: "slider.horizontal.3") }
                Spacer()
                Button { info = current } label: { Image(systemName: "info.circle") }
                Spacer()
                Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
            }
        }
        .fullScreenCover(item: $editing) { item in
            PhotoEditorView(item: item) { reloadToken = UUID() }
        }
        .sheet(item: $info) { item in MetadataEditor(item: item) }
        .sheet(item: $share) { s in ShareSheet(items: s.urls).presentationDetents([.medium, .large]) }
        .confirmationDialog("¿Eliminar esta foto?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let c = current {
                    MediaStore.delete(c, context: context)
                    dismiss()
                }
            }
        }
    }
}

/// Imagen con zoom por pinza, desplazamiento y doble toque.
struct ZoomableImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { v in scale = max(1, min(lastScale * v.magnification, 6)) }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale == 1 { withAnimation { offset = .zero; lastOffset = .zero } }
                                }
                        )
                        // El arrastre solo se activa con zoom, para no bloquear el deslizamiento entre fotos.
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    offset = CGSize(width: lastOffset.width + v.translation.width,
                                                    height: lastOffset.height + v.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset },
                            including: scale > 1 ? .all : .subviews
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring) {
                                if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                                else { scale = 2.5; lastScale = 2.5 }
                            }
                        }
                } else {
                    ProgressView().tint(.white)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .task {
            image = UIImage(contentsOfFile: url.path)
        }
    }
}

struct PhotoEditorView: View {
    let item: MediaItem
    var onSaved: () -> Void
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var original: UIImage?
    @State private var previewBase: UIImage?
    @State private var rendered: UIImage?
    @State private var adj = PhotoAdjustments()
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    if let rendered {
                        Image(uiImage: rendered).resizable().scaledToFit()
                            .transition(.opacity)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxHeight: .infinity)

                Form {
                    Section("Filtro") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(PhotoFilter.allCases) { f in
                                    Button(f.title) { adj.filter = f }
                                        .buttonStyle(.bordered)
                                        .tint(adj.filter == f ? theme.primary : .gray)
                                }
                            }
                        }
                    }
                    Section("Ajustes") {
                        slider("Brillo", value: $adj.brightness, range: -0.5...0.5)
                        slider("Contraste", value: $adj.contrast, range: 0.5...1.5)
                        slider("Saturación", value: $adj.saturation, range: 0...2)
                        HStack {
                            Button { adj.rotationQuarterTurns -= 1 } label: { Label("Rotar", systemImage: "rotate.left") }
                            Spacer()
                            Toggle("Recorte 1:1", isOn: $adj.cropSquare).fixedSize()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(height: 330)
            }
            .navigationTitle("Editar foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restablecer") { adj = PhotoAdjustments() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(saving || original == nil)
                }
            }
            .task {
                original = UIImage(contentsOfFile: item.fileURL.path)
                if let original {
                    // Versión reducida para que la vista previa sea fluida.
                    previewBase = ImageProcessor.render(original, adjustments: PhotoAdjustments(), maxDimension: 1200)
                }
                updatePreview()
            }
            .onChange(of: adj) { updatePreview() }
        }
    }

    private func slider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(String(format: "%.2f", value.wrappedValue))").font(.caption)
            Slider(value: value, in: range)
        }
    }

    private func updatePreview() {
        guard let base = previewBase else { return }
        let a = adj
        Task.detached(priority: .userInitiated) {
            let out = ImageProcessor.render(base, adjustments: a)
            await MainActor.run { rendered = out }
        }
    }

    private func save() {
        guard let original else { return }
        saving = true
        let a = adj
        Task.detached(priority: .userInitiated) {
            let out = ImageProcessor.render(original, adjustments: a)
            let data = out?.jpegData(compressionQuality: 0.92)
            await MainActor.run {
                if let data {
                    try? MediaStore.replacePhoto(item, with: data, context: context)
                    if a.filter != .none { item.filterName = a.filter.title }
                    context.saveIfNeeded()
                    onSaved()
                }
                saving = false
                dismiss()
            }
        }
    }
}

struct MetadataEditor: View {
    @ObservedObject var item: MediaItem
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(entity: PersistenceController.albumEntity,
                  sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var albums: FetchedResults<Album>
    @State private var newTag = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    LabeledContent("Archivo", value: item.fileName)
                    LabeledContent("Fecha", value: item.createdAt.formatted(date: .long, time: .shortened))
                    LabeledContent("Tipo", value: item.mediaKind == .photo ? "Foto" : "Audio")
                    if item.mediaKind == .audio { LabeledContent("Duración", value: item.duration.mmss) }
                    if let f = item.filterName { LabeledContent("Filtro", value: f) }
                    LabeledContent("Tamaño", value: ByteCountFormatter.string(
                        fromByteCount: Int64((try? item.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0),
                        countStyle: .file))
                }

                Section("Ubicación") {
                    if item.hasLocation {
                        let coord = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
                        Map(initialPosition: .region(MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800))) {
                            Marker("Captura", coordinate: coord)
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(String(format: "%.5f, %.5f", item.latitude, item.longitude))
                            .font(.caption.monospacedDigit())
                    } else {
                        Text("Sin ubicación registrada").foregroundStyle(.secondary)
                    }
                }

                Section("Álbum") {
                    Picker("Álbum", selection: Binding(get: { item.album }, set: { item.album = $0; context.saveIfNeeded() })) {
                        Text("Ninguno").tag(Album?.none)
                        ForEach(albums) { a in Text(a.name).tag(Optional(a)) }
                    }
                }

                Section("Etiquetas") {
                    ForEach(item.tagList, id: \.self) { tag in
                        Label(tag, systemImage: "tag")
                    }
                    .onDelete { idx in
                        var list = item.tagList
                        list.remove(atOffsets: idx)
                        item.tagList = list
                        context.saveIfNeeded()
                    }
                    HStack {
                        TextField("Nueva etiqueta", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .onSubmit(addTag)
                        Button("Agregar", action: addTag).disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Detalles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: " ")
        guard !tag.isEmpty, !item.tagList.contains(tag) else { return }
        item.tagList.append(tag)
        context.saveIfNeeded()
        newTag = ""
    }
}
