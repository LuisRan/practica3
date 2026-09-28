/// Entidades del dominio. No dependen de Flutter ni de ninguna librería
/// de persistencia (regla de dependencia de Clean Architecture).
library;

enum MediaType { photo, audio }

class MediaItem {
  const MediaItem({
    this.id,
    required this.type,
    required this.fileName,
    required this.createdAt,
    this.durationMs = 0,
    this.filter,
    this.tags = const [],
    this.albumId,
  });

  final int? id;
  final MediaType type;

  /// Nombre del archivo dentro del directorio de medios (ruta relativa).
  final String fileName;
  final DateTime createdAt;
  final int durationMs;
  final String? filter;
  final List<String> tags;
  final int? albumId;

  bool get isPhoto => type == MediaType.photo;

  MediaItem copyWith({
    int? id,
    List<String>? tags,
    int? albumId,
    bool clearAlbum = false,
    String? filter,
    int? durationMs,
  }) {
    return MediaItem(
      id: id ?? this.id,
      type: type,
      fileName: fileName,
      createdAt: createdAt,
      durationMs: durationMs ?? this.durationMs,
      filter: filter ?? this.filter,
      tags: tags ?? this.tags,
      albumId: clearAlbum ? null : (albumId ?? this.albumId),
    );
  }
}

class Album {
  const Album({this.id, required this.name, required this.createdAt});
  final int? id;
  final String name;
  final DateTime createdAt;
}
