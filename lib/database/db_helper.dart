import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Note {
  final int? id;
  final String title;
  final String content;
  final String updatedAt;
  final bool isPinned;
  final String folder;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isPinned = false,
    this.folder = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'updated_at': updatedAt,
      'is_pinned': isPinned ? 1 : 0,
      'folder': folder,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      updatedAt: map['updated_at'],
      isPinned: (map['is_pinned'] ?? 0) == 1,
      folder: map['folder'] ?? '',
    );
  }
}

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notes.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            folder TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE folders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE notes ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE notes ADD COLUMN folder TEXT NOT NULL DEFAULT ''");
          } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS folders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE
              )
            ''');
          } catch (_) {}
        }
      },
    );
  }

  static Future<int> insert(Note note) async {
    final db = await database;
    return db.insert('notes', note.toMap());
  }

  static Future<List<Note>> getAll({String? folder}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (folder != null && folder.isNotEmpty) {
      maps = await db.query(
        'notes',
        where: 'folder = ?',
        whereArgs: [folder],
        orderBy: 'is_pinned DESC, updated_at DESC',
      );
    } else {
      maps = await db.query('notes', orderBy: 'is_pinned DESC, updated_at DESC');
    }
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  static Future<void> update(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  static Future<void> delete(int id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAll() async {
    final db = await database;
    await db.delete('notes');
  }

  static Future<void> togglePin(int id, bool currentState) async {
    final db = await database;
    await db.update(
      'notes',
      {'is_pinned': currentState ? 0 : 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<String>> getFolders() async {
    final db = await database;
    final maps = await db.query('folders', orderBy: 'name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  static Future<void> insertFolder(String name) async {
    final db = await database;
    await db.insert(
      'folders',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> deleteFolder(String name) async {
    final db = await database;
    await db.delete('folders', where: 'name = ?', whereArgs: [name]);
    await db.update(
      'notes',
      {'folder': ''},
      where: 'folder = ?',
      whereArgs: [name],
    );
  }
}
