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
    // Detect desktop (Linux, Windows, macOS)
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<Task> create(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
    return task;
  }

  Future<Task?> read(String id) async {
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
    final db = await database;
    return db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> delete(String id) async {
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
        if (!item.containsKey('id') ||
            !item.containsKey('title') ||
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
            'completed': item['completed'],
            'priority': item['priority'],
            'createdAt': item['createdAt'],
          });
          await txn.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
