import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/task.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, fileName);
    return await openDatabase(path, version: 5, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        category TEXT,
        photoPath TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT
      );
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Migração incremental, adicionando colunas se ainda não existirem.
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN category TEXT');
        // Define categoria padrão para existentes
        await db.execute("UPDATE tasks SET category = 'uncategorized' WHERE category IS NULL");
      } catch (_) {}
    }
  }

  Future<Task> create(Task task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap()..remove('id'));
    return task.copyWith(id: id);
  }

  Future<Task?> read(int id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> update(Task task) async {
    if (task.id == null) return 0;
    final db = await database;
    final map = task.toMap()..remove('id');
    return db.update('tasks', map, where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> delete(int? id) async {
    if (id == null) return 0;
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<File> _exportFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(join(directory.path, 'tasks_export.json'));
  }

  Future<File> exportToJson() async {
    final tasks = await readAll();
    final file = await _exportFile();
    final json = jsonEncode({'tasks': tasks.map((t) => t.toMap()).toList()});
    await file.writeAsString(json);
    return file;
  }

  Future<int> importFromJson({File? file}) async {
    final targetFile = file ?? await _exportFile();
    if (!await targetFile.exists()) {
      throw Exception('Arquivo não encontrado: ${targetFile.path}');
    }

    final content = await targetFile.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map || decoded['tasks'] is! List) {
      throw Exception('Formato inválido: objeto "tasks" não encontrado');
    }

    final List tasksList = decoded['tasks'];
    final db = await database;
    int imported = 0;

    await db.transaction((txn) async {
      for (final item in tasksList) {
        if (item is! Map) continue;
        if (!item.containsKey('title') ||
            !item.containsKey('completed') ||
            !item.containsKey('priority') ||
            !item.containsKey('createdAt')) {
          continue;
        }
        try {
          final task = Task.fromMap({
            'id': item['id'],
            'title': item['title'],
            'description': item['description'] ?? '',
            'priority': item['priority'],
            'completed': item['completed'],
            'createdAt': item['createdAt'],
            'category': item['category'],
            'photoPath': item['photoPath'],
            'completedAt': item['completedAt'],
            'completedBy': item['completedBy'],
            'latitude': item['latitude']?.toDouble(),
            'longitude': item['longitude']?.toDouble(),
            'locationName': item['locationName'],
          });
          await txn.insert(
            'tasks',
            task.toMap()..remove('id'),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          imported++;
        } catch (_) {
          // Ignora itens inválidos individuais
        }
      }
    });

    return imported;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
