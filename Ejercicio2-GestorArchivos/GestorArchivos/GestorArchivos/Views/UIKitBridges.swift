//
//  UIKitBridges.swift
//  Puentes UIKit -> SwiftUI:
//   - DocumentPicker: UIDocumentPickerViewController (importar archivos / elegir carpeta externa).
//   - QuickLookPreview: QLPreviewController (vista previa nativa).
//   - ShareSheet: UIActivityViewController (compartir / exportar).
//

import SwiftUI
import UIKit
import QuickLook
import UniformTypeIdentifiers

// MARK: - UIDocumentPickerViewController

struct DocumentPicker: UIViewControllerRepresentable {
    enum Mode {
        case importFiles      // Copia archivos desde Archivos / iCloud Drive
        case openFolder       // Obtiene acceso a una carpeta externa (security-scoped)
    }

    let mode: Mode
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch mode {
        case .importFiles:
            // asCopy: true -> el sistema entrega una copia dentro de nuestro sandbox (tmp/Inbox).
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            picker.allowsMultipleSelection = true
        case .openFolder:
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
            picker.allowsMultipleSelection = false
        }
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

// MARK: - QLPreviewController

struct QuickLookPreview: UIViewControllerRepresentable {
    let urls: [URL]
    var initialIndex: Int = 0

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.currentPreviewItemIndex = initialIndex
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak controller] _ in controller?.dismiss(animated: true) })
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(urls: urls) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let urls: [URL]
        init(urls: [URL]) { self.urls = urls }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { urls.count }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            urls[index] as NSURL
        }
    }

    static func canPreview(_ url: URL) -> Bool {
        QLPreviewController.canPreview(url as NSURL)
    }
}

// MARK: - UIActivityViewController

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Wrapper identificable para presentar hojas con `.sheet(item:)`.
struct SheetURLs: Identifiable {
    let id = UUID()
    let urls: [URL]
}
