//
//  MediaStore.swift
//  Guarda los archivos capturados en Documents/Media/{Photos,Audio},
//  genera miniaturas (Library/Caches/Thumbs + NSCache) y crea/borra los
//  registros de Core Data asociados.
//

import CoreData
import CoreLocation
import UIKit
import ImageIO

enum MediaStore {
    static var root: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Media", isDirectory: true)
    }

    static func directory(for kind: MediaItem.Kind) -> URL {
        let dir = root.appendingPathComponent(kind == .photo ? "Photos" : "Audio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var thumbsDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thumbs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func newFileName(kind: MediaItem.Kind, ext: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        let prefix = kind == .photo ? "IMG" : "AUD"
        return "\(prefix)_\(f.string(from: Date()))_\(UUID().uuidString.prefix(4)).\(ext)"
    }

    // MARK: - Creación de registros

    @discardableResult
    static func savePhoto(_ data: Data, filter: String?, location: CLLocation?, album: Album?,
                          context: NSManagedObjectContext) throws -> MediaItem {
        let name = newFileName(kind: .photo, ext: "jpg")
        let url = directory(for: .photo).appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        let item = MediaItem(entity: PersistenceController.mediaEntity, insertInto: context)
        item.id = UUID()
        item.kind = MediaItem.Kind.photo.rawValue
        item.fileName = name
        item.createdAt = Date()
        item.filterName = filter
        item.tags = ""
        item.album = album
        apply(location, to: item)
        context.saveIfNeeded()
        _ = ThumbnailStore.shared.thumbnail(for: item) // pre-genera la miniatura
        return item
    }

    @discardableResult
    static func registerAudio(at url: URL, duration: Double, location: CLLocation?, album: Album?,
                              context: NSManagedObjectContext) -> MediaItem {
        let item = MediaItem(entity: PersistenceController.mediaEntity, insertInto: context)
        item.id = UUID()
        item.kind = MediaItem.Kind.audio.rawValue
        item.fileName = url.lastPathComponent
        item.createdAt = Date()
        item.duration = duration
        item.tags = ""
        item.album = album
        apply(location, to: item)
        context.saveIfNeeded()
        return item
    }

    private static func apply(_ location: CLLocation?, to item: MediaItem) {
        if let location {
            item.latitude = location.coordinate.latitude
            item.longitude = location.coordinate.longitude
            item.hasLocation = true
        } else {
            item.hasLocation = false
        }
    }

    static func delete(_ item: MediaItem, context: NSManagedObjectContext) {
        try? FileManager.default.removeItem(at: item.fileURL)
        ThumbnailStore.shared.remove(for: item)
        context.delete(item)
        context.saveIfNeeded()
    }

    /// Sobrescribe la foto (después de editarla) e invalida su miniatura.
    static func replacePhoto(_ item: MediaItem, with data: Data, context: NSManagedObjectContext) throws {
        try data.write(to: item.fileURL, options: .atomic)
        ThumbnailStore.shared.remove(for: item)
        context.saveIfNeeded()
    }

    // MARK: - Importar

    /// Importa un archivo de audio externo (fileImporter) copiándolo al sandbox.
    static func importAudio(from external: URL, context: NSManagedObjectContext) throws -> MediaItem {
        let accessing = external.startAccessingSecurityScopedResource()
        defer { if accessing { external.stopAccessingSecurityScopedResource() } }
        let ext = external.pathExtension.isEmpty ? "m4a" : external.pathExtension
        let name = newFileName(kind: .audio, ext: ext)
        let target = directory(for: .audio).appendingPathComponent(name)
        try FileManager.default.copyItem(at: external, to: target)
        let duration = AudioDuration.of(target)
        let item = registerAudio(at: target, duration: duration, location: nil, album: nil, context: context)
        item.tags = "importado"
        context.saveIfNeeded()
        return item
    }

    // MARK: - Uso de almacenamiento

    static func totalSize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

import AVFoundation

enum AudioDuration {
    static func of(_ url: URL) -> Double {
        (try? AVAudioPlayer(contentsOf: url).duration) ?? 0
    }
}

/// Miniaturas para la galería: memoria (NSCache) + disco (Caches/Thumbs).
final class ThumbnailStore {
    static let shared = ThumbnailStore()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.countLimit = 400 }

    private func thumbURL(_ item: MediaItem) -> URL {
        MediaStore.thumbsDirectory.appendingPathComponent(item.id.uuidString + ".jpg")
    }

    func cached(for item: MediaItem) -> UIImage? {
        cache.object(forKey: item.id.uuidString as NSString)
    }

    @discardableResult
    func thumbnail(for item: MediaItem, maxPixel: CGFloat = 360) -> UIImage? {
        guard item.mediaKind == .photo else { return nil }
        let key = item.id.uuidString as NSString
        if let img = cache.object(forKey: key) { return img }
        let disk = thumbURL(item)
        if let img = UIImage(contentsOfFile: disk.path) {
            cache.setObject(img, forKey: key)
            return img
        }
        guard let source = CGImageSourceCreateWithURL(item.fileURL as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
              ] as CFDictionary) else { return nil }
        let img = UIImage(cgImage: cg)
        cache.setObject(img, forKey: key)
        if let data = img.jpegData(compressionQuality: 0.8) { try? data.write(to: disk, options: .atomic) }
        return img
    }

    func remove(for item: MediaItem) {
        cache.removeObject(forKey: item.id.uuidString as NSString)
        try? FileManager.default.removeItem(at: thumbURL(item))
    }

    func clearAll() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: MediaStore.thumbsDirectory)
    }
}
