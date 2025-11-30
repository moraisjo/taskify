import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqlite_api.dart';

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
    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        // Aumenta tolerância a locks em desktop e habilita WAL para melhor concorrência.
        await db.execute('PRAGMA busy_timeout = 5000');
        await db.execute('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remoteId TEXT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        version INTEGER NOT NULL,
        syncStatus TEXT NOT NULL,
        category TEXT,
        photoPath TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT
      );

      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER,
        operation TEXT NOT NULL,
        payload TEXT,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL
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
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE tasks ADD COLUMN updatedAt TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tasks ADD COLUMN version INTEGER");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE tasks ADD COLUMN syncStatus TEXT");
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            taskId INTEGER,
            operation TEXT NOT NULL,
            payload TEXT,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL
          );
        ''');
      } catch (_) {}
      try {
        await db.execute("UPDATE tasks SET updatedAt = createdAt WHERE updatedAt IS NULL");
        await db.execute("UPDATE tasks SET version = 1 WHERE version IS NULL");
        await db.execute("UPDATE tasks SET syncStatus = 'synced' WHERE syncStatus IS NULL");
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE tasks ADD COLUMN remoteId TEXT');
      } catch (_) {}
    }
  }

  Future<Task> create(Task task) async {
    final db = await database;
    final now = DateTime.now();
    final map = task
        .copyWith(
          updatedAt: now,
          version: task.version,
          syncStatus: task.syncStatus,
        )
        .toMap()
      ..remove('id');
    final id = await db.insert('tasks', map);
    return task.copyWith(id: id, updatedAt: now);
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
    const orderBy = 'updatedAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> update(Task task) async {
    if (task.id == null) return 0;
    final db = await database;
    final updated = task.copyWith(
      updatedAt: DateTime.now(),
      version: task.version + 1,
    );
    final map = updated.toMap()..remove('id');
    return db.update('tasks', map, where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> delete(int? id) async {
    if (id == null) return 0;
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== Fila de sincronização =====================

  Future<int> addToSyncQueue({
    required String operation, // CREATE, UPDATE, DELETE
    required Task task,
  }) async {
    final db = await database;
    final payload = jsonEncode(task.toMap());
    return db.insert('sync_queue', {
      'taskId': task.id,
      'operation': operation,
      'payload': payload,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await database;
    return db.query(
      'sync_queue',
      where: 'status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'createdAt ASC',
    );
  }

  Future<int> markQueueItemStatus(int id, String status) async {
    final db = await database;
    return db.update('sync_queue', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> removeFromSyncQueue(int id) async {
    final db = await database;
    return db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
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
            'remoteId': item['remoteId'],
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
