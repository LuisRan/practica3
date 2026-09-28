//
//  UIKitBridges.swift
//  - CameraPreview: AVCaptureVideoPreviewLayer dentro de SwiftUI.
//  - PhotoLibraryPicker: PHPickerViewController (fuente alternativa en el simulador).
//  - ShareSheet: UIActivityViewController para exportar.
//

import SwiftUI
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var selectionLimit = 10
    let onPick: ([Data]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([Data]) -> Void
        init(onPick: @escaping ([Data]) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // La hoja se cierra desde SwiftUI en `onPick` (también al cancelar, con lista vacía).
            guard !results.isEmpty else { onPick([]); return }
            let group = DispatchGroup()
            var datas: [Data] = []
            let lock = NSLock()
            for result in results {
                let provider = result.itemProvider
                guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { continue }
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    // Se normaliza a JPEG para que todas las fotos tengan el mismo formato.
                    if let data, let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.92) {
                        lock.lock(); datas.append(jpeg); lock.unlock()
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) { self.onPick(datas) }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}
