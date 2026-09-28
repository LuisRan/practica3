//
//  FileService.swift
//  Operaciones sobre el sistema de archivos del sandbox de iOS usando FileManager.
//  Nunca se accede a rutas fuera del contenedor de la app, salvo URLs externas
//  obtenidas mediante UIDocumentPicker (security-scoped).
//

import Foundation
import UIKit

enum FileServiceError: LocalizedError {
    case alreadyExists(String)
    case invalidName
    case notFound
    case outsideSandbox
    case unreadable(String)
    case unsupported(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let name): return "Ya existe un elemento llamado “\(name)”."
        case .invalidName: return "El nombre no es válido. No uses “/” ni lo dejes vacío."
        case .notFound: return "El archivo ya no existe."
        case .outsideSandbox: return "Operación no permitida fuera del contenedor de la app."
        case .unreadable(let name): return "No se pudo leer “\(name)”. Puede estar dañado o no ser accesible."
        case .unsupported(let name): return "El tipo de archivo de “\(name)” no está soportado para esta vista."
        case .underlying(let error): return error.localizedDescription
        }
    }
}

/// Ubicaciones raíz accesibles dentro del sandbox.
enum SandboxLocation: String, CaseIterable, Identifiable {
    case documents, inbox, tmp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: return "Documentos"
        case .inbox: return "Inbox"
        case .tmp: return "Temporales (tmp)"
        }
    }

    var icon: String {
        switch self {
        case .documents: return "folder.fill"
        case .inbox: return "tray.and.arrow.down.fill"
        case .tmp: return "clock.arrow.circlepath"
        }
    }

    var url: URL {
        switch self {
        case .documents: return FileService.documentsURL
        case .inbox: return FileService.documentsURL.appendingPathComponent("Inbox", isDirectory: true)
        case .tmp: return FileManager.default.temporaryDirectory
        }
    }
}

final class FileService {
    static let shared = FileService()
    private let fm = FileManager.default

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Raíz del contenedor de la app (NSHomeDirectory()).
    static var containerURL: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
    }

    // MARK: - Utilidades de ruta

    /// Verifica que una URL esté dentro del contenedor de la app.
    func isInsideSandbox(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let root = FileService.containerURL.resolvingSymlinksInPath().path
        let tmp = fm.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        return path.hasPrefix(root) || path.hasPrefix(tmp)
    }

    /// Ruta legible relativa al contenedor, p. ej. "Documents/Proyectos".
    func displayPath(for url: URL) -> String {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let root = FileService.containerURL.resolvingSymlinksInPath().path
        if path.hasPrefix(root) {
            let rel = String(path.dropFirst(root.count))
            return rel.isEmpty ? "/" : rel
        }
        return path
    }

    // MARK: - Listado

    func contents(of directory: URL, showHidden: Bool = false) throws -> [FileItem] {
        do {
            let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
            let urls = try fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey],
                options: options)
            return urls.map(FileItem.init(url:))
        } catch {
            throw FileServiceError.underlying(error)
        }
    }

    func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    // MARK: - Gestión

    @discardableResult
    func createFolder(named name: String, in directory: URL) throws -> URL {
        let clean = try validate(name)
        let target = directory.appendingPathComponent(clean, isDirectory: true)
        guard !fm.fileExists(atPath: target.path) else { throw FileServiceError.alreadyExists(clean) }
        do {
            try fm.createDirectory(at: target, withIntermediateDirectories: false)
            return target
        } catch { throw FileServiceError.underlying(error) }
    }

    @discardableResult
    func createTextFile(named name: String, contents: String, in directory: URL) throws -> URL {
        let clean = try validate(name)
        let target = directory.appendingPathComponent(clean)
        guard !fm.fileExists(atPath: target.path) else { throw FileServiceError.alreadyExists(clean) }
        do {
            try contents.write(to: target, atomically: true, encoding: .utf8)
            return target
        } catch { throw FileServiceError.underlying(error) }
    }

    @discardableResult
    func rename(_ url: URL, to newName: String) throws -> URL {
        let clean = try validate(newName)
        let target = url.deletingLastPathComponent().appendingPathComponent(clean)
        if target == url { return url }
        guard !fm.fileExists(atPath: target.path) else { throw FileServiceError.alreadyExists(clean) }
        do {
            try fm.moveItem(at: url, to: target)
            return target
        } catch { throw FileServiceError.underlying(error) }
    }

    @discardableResult
    func copy(_ url: URL, to directory: URL) throws -> URL {
        guard fm.fileExists(atPath: url.path) else { throw FileServiceError.notFound }
        let target = uniqueURL(for: url.lastPathComponent, in: directory)
        do {
            try fm.copyItem(at: url, to: target)
            return target
        } catch { throw FileServiceError.underlying(error) }
    }

    @discardableResult
    func move(_ url: URL, to directory: URL) throws -> URL {
        guard fm.fileExists(atPath: url.path) else { throw FileServiceError.notFound }
        // Evita mover una carpeta dentro de sí misma.
        if directory.standardizedFileURL.path.hasPrefix(url.standardizedFileURL.path + "/")
            || directory.standardizedFileURL == url.standardizedFileURL {
            throw FileServiceError.underlying(NSError(domain: "GestorArchivos", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No se puede mover una carpeta dentro de sí misma."]))
        }
        if url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL { return url }
        let target = uniqueURL(for: url.lastPathComponent, in: directory)
        do {
            try fm.moveItem(at: url, to: target)
            return target
        } catch { throw FileServiceError.underlying(error) }
    }

    func delete(_ url: URL) throws {
        guard isInsideSandbox(url) else { throw FileServiceError.outsideSandbox }
        do { try fm.removeItem(at: url) } catch { throw FileServiceError.underlying(error) }
    }

    /// Importa (copia) un archivo externo obtenido con UIDocumentPicker.
    @discardableResult
    func importExternal(_ url: URL, into directory: URL) throws -> URL {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        var coordError: NSError?
        var result: Result<URL, Error> = .failure(FileServiceError.unreadable(url.lastPathComponent))
        // NSFileCoordinator garantiza una lectura consistente (iCloud Drive / otros proveedores).
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordError) { readURL in
            do {
                let target = uniqueURL(for: url.lastPathComponent, in: directory)
                try fm.copyItem(at: readURL, to: target)
                result = .success(target)
            } catch {
                result = .failure(FileServiceError.underlying(error))
            }
        }
        if let coordError { throw FileServiceError.underlying(coordError) }
        return try result.get()
    }

    // MARK: - Lectura

    /// Lee un archivo de texto probando varias codificaciones. Limita a 2 MB para no bloquear la UI.
    func readText(_ url: URL, limit: Int = 2_000_000) throws -> (text: String, truncated: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw FileServiceError.unreadable(url.lastPathComponent)
        }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: limit + 1)) ?? Data()
        let truncated = data.count > limit
        let slice = truncated ? data.prefix(limit) : data
        for encoding in [String.Encoding.utf8, .utf16, .isoLatin1, .windowsCP1252] {
            if let text = String(data: slice, encoding: encoding) {
                return (text, truncated)
            }
        }
        throw FileServiceError.unreadable(url.lastPathComponent)
    }

    func writeText(_ text: String, to url: URL) throws {
        do { try text.write(to: url, atomically: true, encoding: .utf8) }
        catch { throw FileServiceError.underlying(error) }
    }

    // MARK: - Auxiliares

    func validate(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.contains("/"), clean != ".", clean != ".." else {
            throw FileServiceError.invalidName
        }
        return clean
    }

    /// Devuelve una URL que no exista, agregando " (2)", " (3)"... si es necesario.
    func uniqueURL(for name: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(name)
        guard fm.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var i = 2
        repeat {
            let newName = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            i += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    /// Crea contenido de ejemplo la primera vez que se abre la app.
    func seedSampleContentIfNeeded() {
        let key = "sampleContentCreated"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let docs = FileService.documentsURL
        let ejemplos = docs.appendingPathComponent("Ejemplos", isDirectory: true)
        try? fm.createDirectory(at: ejemplos, withIntermediateDirectories: true)
        try? fm.createDirectory(at: docs.appendingPathComponent("Proyectos", isDirectory: true),
                                withIntermediateDirectories: true)

        let readme = """
        # Gestor de Archivos — Práctica 3

        Bienvenido. Esta app explora el **sandbox** de iOS:

        - Documents: archivos del usuario (visibles en la app Archivos).
        - Documents/Inbox: archivos recibidos desde otras apps.
        - tmp: archivos temporales que el sistema puede borrar.

        Gestos: desliza para eliminar, mantén presionado para el menú contextual
        y desliza hacia abajo para actualizar.
        """
        try? readme.write(to: docs.appendingPathComponent("Bienvenida.md"), atomically: true, encoding: .utf8)

        let json = """
        {
          "escuela": "ESCOM",
          "instituto": "IPN",
          "practica": 3,
          "temas": ["Guinda", "Azul"]
        }
        """
        try? json.write(to: ejemplos.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        let swift = """
        import Foundation

        struct Saludo {
            let nombre: String
            func decir() -> String { "Hola, \\(nombre)" }
        }

        print(Saludo(nombre: "ESCOM").decir())
        """
        try? swift.write(to: ejemplos.appendingPathComponent("Saludo.swift"), atomically: true, encoding: .utf8)
        try? "Nota de texto plano.\nLínea 2.".write(to: ejemplos.appendingPathComponent("nota.txt"),
                                                    atomically: true, encoding: .utf8)

        // Imagen de ejemplo generada por código (degradado con texto).
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800))
        let image = renderer.image { ctx in
            let colors = [UIColor(hex: 0x6F1D46).cgColor, UIColor(hex: 0x005B9F).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1200, y: 800), options: [])
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 110, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            ("IPN · ESCOM" as NSString).draw(at: CGPoint(x: 140, y: 320), withAttributes: attrs)
        }
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: ejemplos.appendingPathComponent("imagen_ejemplo.jpg"))
        }
        // PDF de ejemplo para probar Quick Look.
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let pdfData = pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 28, weight: .bold)]
            ("Documento PDF de ejemplo" as NSString).draw(at: CGPoint(x: 60, y: 80), withAttributes: attrs)
            ("Vista previa con QLPreviewController." as NSString)
                .draw(at: CGPoint(x: 60, y: 130), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
        try? pdfData.write(to: ejemplos.appendingPathComponent("documento.pdf"))
        try? "archivo temporal".write(to: fm.temporaryDirectory.appendingPathComponent("temporal.txt"),
                                      atomically: true, encoding: .utf8)
        UserDefaults.standard.set(true, forKey: key)
    }
}
