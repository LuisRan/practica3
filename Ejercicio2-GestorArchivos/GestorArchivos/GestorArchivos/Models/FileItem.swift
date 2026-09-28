//
//  FileItem.swift
//  Modelo de un archivo o carpeta del sistema de archivos.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let contentType: UTType?
    /// Número de elementos (solo carpetas).
    let childCount: Int?

    var id: URL { url }

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey
        ])
        let dir = values?.isDirectory ?? false
        self.isDirectory = dir
        self.size = Int64(values?.fileSize ?? 0)
        self.modificationDate = values?.contentModificationDate ?? .distantPast
        self.contentType = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        if dir {
            self.childCount = (try? FileManager.default.contentsOfDirectory(atPath: url.path).count)
        } else {
            self.childCount = nil
        }
    }

    // MARK: - Clasificación por tipo (UTType)

    enum Kind {
        case folder, text, image, pdf, audio, video, archive, code, other
    }

    var kind: Kind {
        if isDirectory { return .folder }
        guard let type = contentType else { return .other }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .archive) || type.conforms(to: .zip) { return .archive }
        if type.conforms(to: .sourceCode) || type.conforms(to: .json)
            || type.conforms(to: .xml) || type.conforms(to: .propertyList) { return .code }
        if type.conforms(to: .text) { return .text }
        if FileItem.textExtensions.contains(url.pathExtension.lowercased()) { return .text }
        return .other
    }

    /// Extensiones que se tratan como texto aunque el sistema no las reconozca.
    static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "swift", "json", "xml", "csv", "log", "yml", "yaml",
        "kt", "java", "dart", "py", "js", "ts", "html", "css", "sh", "plist", "ini", "conf"
    ]

    var isTextLike: Bool { kind == .text || kind == .code }

    /// Símbolo SF según el tipo de archivo.
    var iconName: String {
        switch kind {
        case .folder: return "folder.fill"
        case .text: return "doc.text.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo.fill"
        case .pdf: return "doc.richtext.fill"
        case .audio: return "waveform"
        case .video: return "film.fill"
        case .archive: return "doc.zipper"
        case .other: return "doc.fill"
        }
    }

    var iconColor: Color {
        switch kind {
        case .folder: return .accentColor
        case .text: return .gray
        case .code: return .orange
        case .image: return .green
        case .pdf: return .red
        case .audio: return .pink
        case .video: return .purple
        case .archive: return .brown
        case .other: return .secondary
        }
    }

    var typeDescription: String {
        if isDirectory { return "Carpeta" }
        return contentType?.localizedDescription ?? url.pathExtension.uppercased()
    }

    var formattedSize: String {
        if isDirectory {
            let n = childCount ?? 0
            return n == 1 ? "1 elemento" : "\(n) elementos"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Criterios de ordenamiento disponibles.
enum SortOption: String, CaseIterable, Identifiable {
    case name, date, size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Nombre"
        case .date: return "Fecha"
        case .size: return "Tamaño"
        }
    }

    var icon: String {
        switch self {
        case .name: return "textformat"
        case .date: return "calendar"
        case .size: return "internaldrive"
        }
    }

    func sort(_ items: [FileItem], ascending: Bool) -> [FileItem] {
        let sorted = items.sorted { a, b in
            // Las carpetas siempre van primero.
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            let result: Bool
            switch self {
            case .name:
                result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .date:
                result = a.modificationDate < b.modificationDate
            case .size:
                result = a.size < b.size
            }
            return ascending ? result : !result
        }
        return sorted
    }
}
