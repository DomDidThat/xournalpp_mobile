import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:xournalpp/src/Notebook.dart';

class NotebookDatabase {
  NotebookDatabase._();
  static final NotebookDatabase instance = NotebookDatabase._();

  static const _dbName = 'notebooks.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, _dbName),
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notebooks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            cover_color INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            page_count INTEGER NOT NULL DEFAULT 1,
            xopp_data BLOB
          )
        ''');
        await db.execute('''
          CREATE TABLE page_thumbnails (
            notebook_id TEXT NOT NULL,
            page_index INTEGER NOT NULL,
            thumbnail BLOB,
            PRIMARY KEY (notebook_id, page_index)
          )
        ''');
      },
    );
  }

  // ── Notebooks ──────────────────────────────────────────────────────────────

  Future<Notebook> createNotebook({
    required String title,
    required Color coverColor,
    required Uint8List xoppData,
    int pageCount = 1,
  }) async {
    final db = await _database;
    final now = DateTime.now();
    final notebook = Notebook(
      id: const Uuid().v4(),
      title: title,
      coverColor: coverColor,
      createdAt: now,
      updatedAt: now,
      pageCount: pageCount,
      xoppData: xoppData,
    );
    await db.insert('notebooks', notebook.toMap());
    return notebook;
  }

  /// Returns all notebooks ordered by most recently updated.
  /// Does not include xopp_data — call [loadNotebook] to fetch the full blob.
  Future<List<Notebook>> listNotebooks() async {
    final db = await _database;
    final rows = await db.query(
      'notebooks',
      columns: ['id', 'title', 'cover_color', 'created_at', 'updated_at', 'page_count'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Notebook.fromMap).toList();
  }

  /// Loads the full notebook including xopp_data blob.
  Future<Notebook?> loadNotebook(String id) async {
    final db = await _database;
    final rows = await db.query(
      'notebooks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Notebook.fromMap(rows.first);
  }

  Future<void> saveNotebook({
    required String id,
    required Uint8List xoppData,
    required int pageCount,
  }) async {
    final db = await _database;
    await db.update(
      'notebooks',
      {
        'xopp_data': xoppData,
        'page_count': pageCount,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> renameNotebook(String id, String newTitle) async {
    final db = await _database;
    await db.update(
      'notebooks',
      {'title': newTitle, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCoverColor(String id, Color color) async {
    final db = await _database;
    await db.update(
      'notebooks',
      {'cover_color': color.toARGB32(), 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNotebook(String id) async {
    final db = await _database;
    await db.delete('notebooks', where: 'id = ?', whereArgs: [id]);
    await db.delete('page_thumbnails', where: 'notebook_id = ?', whereArgs: [id]);
  }

  // ── Thumbnails ─────────────────────────────────────────────────────────────

  Future<void> upsertThumbnail({
    required String notebookId,
    required int pageIndex,
    required Uint8List pngBytes,
  }) async {
    final db = await _database;
    await db.insert(
      'page_thumbnails',
      {
        'notebook_id': notebookId,
        'page_index': pageIndex,
        'thumbnail': pngBytes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Uint8List?> getThumbnail({
    required String notebookId,
    required int pageIndex,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'page_thumbnails',
      columns: ['thumbnail'],
      where: 'notebook_id = ? AND page_index = ?',
      whereArgs: [notebookId, pageIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['thumbnail'] as Uint8List?;
  }

  /// Returns all thumbnails for a notebook ordered by page_index.
  Future<List<MapEntry<int, Uint8List?>>> listThumbnails(String notebookId) async {
    final db = await _database;
    final rows = await db.query(
      'page_thumbnails',
      columns: ['page_index', 'thumbnail'],
      where: 'notebook_id = ?',
      whereArgs: [notebookId],
      orderBy: 'page_index ASC',
    );
    return rows
        .map((r) => MapEntry(r['page_index'] as int, r['thumbnail'] as Uint8List?))
        .toList();
  }

  Future<void> deleteThumbnail({
    required String notebookId,
    required int pageIndex,
  }) async {
    final db = await _database;
    await db.delete(
      'page_thumbnails',
      where: 'notebook_id = ? AND page_index = ?',
      whereArgs: [notebookId, pageIndex],
    );
  }

  /// Removes thumbnails for pages beyond [newPageCount] (used after page deletion).
  Future<void> trimThumbnails({
    required String notebookId,
    required int newPageCount,
  }) async {
    final db = await _database;
    await db.delete(
      'page_thumbnails',
      where: 'notebook_id = ? AND page_index >= ?',
      whereArgs: [notebookId, newPageCount],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
