//
//  Persistence.swift
//  Core Data para los metadatos de las capturas (fecha, ubicación, etiquetas, álbum).
//  El modelo se define por código (sin .xcdatamodeld) para que sea fácil de revisar:
//
//   MediaItem                      Album
//   ─────────                      ─────
//   id: UUID                       id: UUID
//   kind: String ("photo"/"audio") name: String
//   fileName: String               createdAt: Date
//   createdAt: Date                items <->> MediaItem.album
//   latitude/longitude: Double
//   hasLocation: Bool
//   tags: String (separadas por coma)
//   filterName: String?
//   duration: Double (audio)
//   album -> Album (opcional)
//

import CoreData
import Foundation

@objc(MediaItem)
final class MediaItem: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var kind: String
    @NSManaged var fileName: String
    @NSManaged var createdAt: Date
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var hasLocation: Bool
    @NSManaged var tags: String
    @NSManaged var filterName: String?
    @NSManaged var duration: Double
    @NSManaged var album: Album?

    enum Kind: String { case photo, audio }

    var mediaKind: Kind { Kind(rawValue: kind) ?? .photo }

    var tagList: [String] {
        get {
            tags.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set { tags = newValue.joined(separator: ",") }
    }

    /// Ruta absoluta del archivo (se calcula en cada acceso porque el contenedor puede cambiar).
    var fileURL: URL { MediaStore.directory(for: mediaKind).appendingPathComponent(fileName) }
}

@objc(Album)
final class Album: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var items: Set<MediaItem>
}

struct PersistenceController {
    static let shared = PersistenceController()

    /// Vista previa con datos en memoria.
    static let preview: PersistenceController = PersistenceController(inMemory: true)

    let container: NSPersistentContainer

    // El modelo debe ser único en todo el proceso.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let media = NSEntityDescription()
        media.name = "MediaItem"
        media.managedObjectClassName = NSStringFromClass(MediaItem.self)

        let album = NSEntityDescription()
        album.name = "Album"
        album.managedObjectClassName = NSStringFromClass(Album.self)

        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = false, def: Any? = nil) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            a.defaultValue = def
            return a
        }

        let mediaToAlbum = NSRelationshipDescription()
        mediaToAlbum.name = "album"
        mediaToAlbum.destinationEntity = album
        mediaToAlbum.minCount = 0
        mediaToAlbum.maxCount = 1
        mediaToAlbum.isOptional = true
        mediaToAlbum.deleteRule = .nullifyDeleteRule

        let albumToMedia = NSRelationshipDescription()
        albumToMedia.name = "items"
        albumToMedia.destinationEntity = media
        albumToMedia.minCount = 0
        albumToMedia.maxCount = 0 // to-many
        albumToMedia.isOptional = true
        albumToMedia.deleteRule = .nullifyDeleteRule

        mediaToAlbum.inverseRelationship = albumToMedia
        albumToMedia.inverseRelationship = mediaToAlbum

        media.properties = [
            attr("id", .UUIDAttributeType),
            attr("kind", .stringAttributeType, def: "photo"),
            attr("fileName", .stringAttributeType, def: ""),
            attr("createdAt", .dateAttributeType),
            attr("latitude", .doubleAttributeType, def: 0.0),
            attr("longitude", .doubleAttributeType, def: 0.0),
            attr("hasLocation", .booleanAttributeType, def: false),
            attr("tags", .stringAttributeType, def: ""),
            attr("filterName", .stringAttributeType, optional: true),
            attr("duration", .doubleAttributeType, def: 0.0),
            mediaToAlbum
        ]
        album.properties = [
            attr("id", .UUIDAttributeType),
            attr("name", .stringAttributeType, def: ""),
            attr("createdAt", .dateAttributeType),
            albumToMedia
        ]
        model.entities = [media, album]
        return model
    }()

    static var mediaEntity: NSEntityDescription { model.entitiesByName["MediaItem"]! }
    static var albumEntity: NSEntityDescription { model.entitiesByName["Album"]! }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CamaraMic", managedObjectModel: Self.model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        // Migración ligera automática si el modelo cambia.
        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
        container.loadPersistentStores { _, error in
            if let error {
                // En una app de producción se notificaría al usuario; aquí se registra el error.
                print("Error al cargar Core Data: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

extension NSManagedObjectContext {
    func saveIfNeeded() {
        guard hasChanges else { return }
        do { try save() } catch { print("Error al guardar: \(error)") }
    }
}

// Permite usar ForEach / List directamente con los resultados de @FetchRequest
// (cada objeto ya tiene un `id: UUID`, solo falta declarar la conformidad).
extension MediaItem: Identifiable {}
extension Album: Identifiable {}
