import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/recording.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) {
      return;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'vome.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recordings (
            id            TEXT PRIMARY KEY,
            title         TEXT NOT NULL,
            event_type    TEXT NOT NULL,
            category      TEXT DEFAULT '',
            mood          TEXT DEFAULT 'Neutral',
            status        TEXT DEFAULT 'Pending',
            duration_ms   INTEGER NOT NULL,
            created_at    INTEGER NOT NULL,
            audio_path    TEXT NOT NULL,
            file_size     INTEGER,
            mime_type     TEXT,
            source        TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('DatabaseService.init() must be called first');
    }
    return db;
  }

  Future<void> insertRecording(Recording recording) async {
    await _database.insert(
      'recordings',
      recording.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Recording>> getAllRecordings() async {
    final rows = await _database.query(
      'recordings',
      orderBy: 'created_at DESC',
    );
    return rows.map(Recording.fromMap).toList();
  }

  Future<Recording?> getRecordingById(String id) async {
    final rows = await _database.query(
      'recordings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Recording.fromMap(rows.first);
  }

  Future<List<Recording>> getRecentRecordings({int limit = 10}) async {
    final rows = await _database.query(
      'recordings',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(Recording.fromMap).toList();
  }

  Future<int> countRecordingsSince(DateTime since) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM recordings WHERE created_at >= ?',
      [since.millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> sumDurationSince(DateTime since) async {
    final result = await _database.rawQuery(
      'SELECT COALESCE(SUM(duration_ms), 0) as total FROM recordings WHERE created_at >= ?',
      [since.millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countRecordingsWithPrefix(String prefix) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM recordings WHERE audio_path LIKE ?',
      ['audio/${prefix}_%'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteRecording(String id) async {
    await _database.delete(
      'recordings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
