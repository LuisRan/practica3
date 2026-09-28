//
//  FileDetailView.swift
//  Abre un archivo según su tipo:
//   - Texto / código -> TextFileView
//   - Imagen          -> ImageViewerView (zoom, rotación, ajuste a pantalla)
//   - Otros soportados -> Quick Look (QLPreviewController)
//   - No soportado    -> mensaje de error con opción de compartir
//

import SwiftUI
import QuickLook

struct FileDetailView: View {
    let url: URL
    @EnvironmentObject private var prefs: PreferencesStore
    @State private var shareItems: SheetURLs?
    @State private var previewItems: SheetURLs?
    @State private var showInfo = false

    private var item: FileItem { FileItem(url: url) }

    var body: some View {
        content
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        prefs.toggleFavorite(url)
                    } label: {
                        Image(systemName: prefs.isFavorite(url) ? "star.fill" : "star")
                    }
                    .accessibilityLabel(prefs.isFavorite(url) ? "Quitar de favoritos" : "Agregar a favoritos")

                    Menu {
                        if QuickLookPreview.canPreview(url) {
                            Button { previewItems = SheetURLs(urls: [url]) } label: {
                                Label("Vista rápida (Quick Look)", systemImage: "eye")
                            }
                        }
                        Button { shareItems = SheetURLs(urls: [url]) } label: {
                            Label("Compartir / Exportar", systemImage: "square.and.arrow.up")
                        }
                        Button { showInfo = true } label: {
                            Label("Información", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear { prefs.addRecent(url) }
            .sheet(item: $shareItems) { share in
                ShareSheet(items: share.urls).presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $previewItems) { preview in
                QuickLookPreview(urls: preview.urls).ignoresSafeArea()
            }
            .sheet(isPresented: $showInfo) {
                FileInfoView(item: item)
                    .presentationDetents([.medium])
            }
    }

    @ViewBuilder
    private var content: some View {
        if !FileManager.default.fileExists(atPath: url.path) {
            ContentUnavailableView("Archivo no encontrado", systemImage: "questionmark.folder",
                                   description: Text("El archivo fue movido o eliminado."))
        } else if !FileManager.default.isReadableFile(atPath: url.path) {
            ContentUnavailableView("Sin acceso", systemImage: "lock.fill",
                                   description: Text("La app no tiene permiso para leer este archivo."))
        } else {
            switch item.kind {
            case .text, .code:
                TextFileView(url: url)
            case .image:
                ImageViewerView(url: url)
            default:
                if QuickLookPreview.canPreview(url) {
                    EmbeddedQuickLook(url: url)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 16) {
                        ContentUnavailableView("Tipo no soportado",
                                               systemImage: "doc.questionmark",
                                               description: Text("No hay vista previa para “\(item.typeDescription)”. Puedes compartirlo para abrirlo con otra app."))
                        Button {
                            shareItems = SheetURLs(urls: [url])
                        } label: {
                            Label("Abrir con otra app", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

/// QLPreviewController incrustado en la jerarquía de SwiftUI.
struct EmbeddedQuickLook: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

/// Hoja con metadatos del archivo.
struct FileInfoView: View {
    let item: FileItem

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Nombre", value: item.name)
                LabeledContent("Tipo", value: item.typeDescription)
                LabeledContent("UTType", value: item.contentType?.identifier ?? "desconocido")
                LabeledContent("Tamaño", value: item.formattedSize)
                LabeledContent("Modificado", value: item.modificationDate.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Ubicación", value: FileService.shared.displayPath(for: item.url.deletingLastPathComponent()))
            }
            .navigationTitle("Información")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
