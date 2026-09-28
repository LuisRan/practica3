import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/media_item.dart';
import '../models/media_model.dart';

/// Fuente de datos local con SQLite (sqflite). Funciona sin conexión.
class MediaLocalDataSource {
  static const _dbName = 'camara_mic.db';
  static const _version = 1;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE albums (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE media (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            file_name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            filter TEXT,
            tags TEXT NOT NULL DEFAULT '',
            album_id INTEGER REFERENCES albums(id) ON DELETE SET NULL
          )''');
        await db.execute('CREATE INDEX idx_media_created ON media(created_at DESC)');
      },
    );
  }

  Future<List<MediaItem>> queryMedia({MediaType? type, int? albumId, String? query}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('m.type = ?');
      args.add(type.name);
    }
    if (albumId != null) {
      where.add('m.album_id = ?');
      args.add(albumId);
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      where.add('(m.tags LIKE ? OR m.file_name LIKE ? OR a.name LIKE ?)');
      args.addAll([q, q, q]);
    }
    final rows = await db.rawQuery('''
      SELECT m.* FROM media m LEFT JOIN albums a ON a.id = m.album_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY m.created_at DESC''', args);
    return rows.map(MediaModel.fromMap).toList();
  }

  Future<int> insertMedia(MediaItem item) async =>
      (await database).insert('media', MediaModel.toMap(item));

  Future<void> updateMedia(MediaItem item) async {
    await (await database).update('media', MediaModel.toMap(item), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteMedia(int id) async {
    await (await database).delete('media', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Album>> queryAlbums() async {
    final rows = await (await database).query('albums', orderBy: 'name COLLATE NOCASE');
    return rows.map(AlbumModel.fromMap).toList();
  }

  Future<int> insertAlbum(Album album) async => (await database).insert('albums', AlbumModel.toMap(album));

  Future<void> renameAlbum(int id, String name) async {
    await (await database).update('albums', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAlbum(int id) async {
    final db = await database;
    await db.update('media', {'album_id': null}, where: 'album_id = ?', whereArgs: [id]);
    await db.delete('albums', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<int, int>> albumCounts() async {
    final rows = await (await database)
        .rawQuery('SELECT album_id, COUNT(*) AS c FROM media WHERE album_id IS NOT NULL GROUP BY album_id');
    return {for (final r in rows) r['album_id'] as int: r['c'] as int};
  }
}
