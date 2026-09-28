import '../../domain/entities/media_item.dart';

/// Mapeo entre las entidades del dominio y las filas de SQLite.
class MediaModel {
  static Map<String, Object?> toMap(MediaItem m) => {
        if (m.id != null) 'id': m.id,
        'type': m.type.name,
        'file_name': m.fileName,
        'created_at': m.createdAt.millisecondsSinceEpoch,
        'duration_ms': m.durationMs,
        'filter': m.filter,
        'tags': m.tags.join(','),
        'album_id': m.albumId,
      };

  static MediaItem fromMap(Map<String, Object?> row) => MediaItem(
        id: row['id'] as int?,
        type: MediaType.values.byName(row['type'] as String),
        fileName: row['file_name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        durationMs: (row['duration_ms'] as int?) ?? 0,
        filter: row['filter'] as String?,
        tags: ((row['tags'] as String?) ?? '')
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        albumId: row['album_id'] as int?,
      );
}

class AlbumModel {
  static Map<String, Object?> toMap(Album a) => {
        if (a.id != null) 'id': a.id,
        'name': a.name,
        'created_at': a.createdAt.millisecondsSinceEpoch,
      };

  static Album fromMap(Map<String, Object?> row) => Album(
        id: row['id'] as int?,
        name: row['name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );
}
