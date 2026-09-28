//
//  ThumbnailCache.swift
//  Caché de miniaturas en dos niveles:
//   1. Memoria (NSCache) para acceso inmediato durante el scroll.
//   2. Disco (Library/Caches/Thumbnails) para conservarlas entre sesiones.
//  La clave incluye la fecha de modificación: si el archivo cambia, se regenera.
//

import UIKit
import ImageIO
import CryptoKit
import QuickLookThumbnailing

actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 300
    }

    private func key(for url: URL, size: CGFloat) -> String {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let raw = "\(url.path)|\(date.timeIntervalSince1970)|\(Int(size))"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Devuelve la miniatura (de caché o generándola).
    func thumbnail(for url: URL, size: CGFloat = 120, scale: CGFloat = 3) async -> UIImage? {
        let k = key(for: url, size: size)
        if let img = memory.object(forKey: k as NSString) { return img }

        let file = directory.appendingPathComponent(k + ".jpg")
        if let data = try? Data(contentsOf: file), let img = UIImage(data: data) {
            memory.setObject(img, forKey: k as NSString)
            return img
        }

        guard let img = await generate(url: url, size: size, scale: scale) else { return nil }
        memory.setObject(img, forKey: k as NSString)
        if let data = img.jpegData(compressionQuality: 0.8) {
            try? data.write(to: file, options: .atomic)
        }
        return img
    }

    /// Reduce la imagen con ImageIO (sin cargarla completa en memoria).
    /// Para otros tipos (PDF, video...) usa QLThumbnailGenerator.
    private func generate(url: URL, size: CGFloat, scale: CGFloat) async -> UIImage? {
        let maxPixel = size * scale
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return UIImage(cgImage: cg)
            }
        }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size, height: size),
                                                   scale: scale, representationTypes: .thumbnail)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).uiImage
    }

    /// Tamaño total de la caché en disco.
    func diskUsage() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
