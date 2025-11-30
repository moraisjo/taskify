import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/task.dart';
import 'api_config.dart';
import 'connectivity_service.dart';
import 'database_service.dart';

/// Serviço de sincronização básica (push/pull) com LWW e fila local.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _isSyncing = false;
  Stream<bool>? _connectivityStream;
  final StreamController<bool> _syncCompletionController = StreamController<bool>.broadcast();
  final StreamController<String> _syncMessageController = StreamController<String>.broadcast();

  Stream<bool> get onSyncComplete => _syncCompletionController.stream;
  Stream<String> get onSyncMessage => _syncMessageController.stream;

  Future<void> initialize() async {
    _log('SyncService init usando baseUrl=${ApiConfig.baseUrl}');
    // Inicia monitor de conectividade
    await ConnectivityService.instance.initialize();
    _connectivityStream ??= ConnectivityService.instance.onlineStream;
    _connectivityStream!.listen((isOnline) {
      if (isOnline) {
        sync();
      }
    });
  }

  Future<void> sync() async {
    if (_isSyncing || !ConnectivityService.instance.isOnline) return;
    _isSyncing = true;
    var success = true;
    try {
      _log('Iniciando sync');
      await _pushPending();
      await _pullUpdates();
    } catch (e) {
      success = false;
      _syncMessageController.add('Erro de sync: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      _syncCompletionController.add(success);
    }
  }

  Future<void> _pushPending() async {
    final queue = await DatabaseService.instance.getPendingQueue();
    _log('Processando fila de sync (${queue.length} itens)');
    for (final item in queue) {
      final op = item['operation'] as String?;
      final payloadStr = item['payload'] as String?;
      if (op == null || payloadStr == null) continue;
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final task = Task.fromMap(payload);
      try {
        if (op == 'CREATE') {
          final pushed = await _pushCreate(task);
          await _markSynced(pushed ?? task);
        } else if (op == 'UPDATE') {
          final pushed = await _pushUpdate(task);
          await _markSynced(pushed ?? task);
        } else if (op == 'DELETE') {
          await _pushDelete(task);
        }
        await DatabaseService.instance.markQueueItemStatus(item['id'] as int, 'done');
        await DatabaseService.instance.removeFromSyncQueue(item['id'] as int);
      } catch (e) {
        _log('Erro ao processar item $op: $e');
        _syncMessageController.add('Sync falhou ($op id=${task.id ?? 'novo'}): $e');
        await DatabaseService.instance.markQueueItemStatus(item['id'] as int, 'failed');
      }
    }
  }

  Future<void> _pullUpdates() async {
    try {
      final lastSync = await _readLastSyncTimestamp();
      final uri = Uri.parse('${ApiConfig.baseUrl}/tasks?modifiedSince=$lastSync');
      _log('Pull GET $uri');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        _syncMessageController.add('Pull falhou: status ${response.statusCode}');
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final tasks = (body['tasks'] as List?) ?? [];
      for (final item in tasks) {
        if (item is! Map) continue;
        final serverTask = _taskFromServer(item);
        if (serverTask == null) continue;
        final local = serverTask.id != null
            ? await DatabaseService.instance.read(serverTask.id!)
            : null;
        if (local == null) {
          await DatabaseService.instance.create(serverTask.copyWith(syncStatus: 'synced'));
        } else {
          // LWW: compara updatedAt/version
          final serverTime = serverTask.updatedAt.millisecondsSinceEpoch;
          final localTime = local.updatedAt.millisecondsSinceEpoch;
          if (serverTime > localTime || serverTask.version > local.version) {
            await DatabaseService.instance.update(
              serverTask.copyWith(id: local.id, syncStatus: 'synced'),
            );
          } else if (localTime > serverTime || local.version > serverTask.version) {
            // Local mais novo: reenvia para o servidor
            try {
              await _pushUpdate(local);
              await DatabaseService.instance.update(local.copyWith(syncStatus: 'synced'));
            } catch (_) {
              // deixa local como está; fila/cuidados extras podem ser adicionados
            }
          }
        }
      }

      await _writeLastSyncTimestamp(DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _syncMessageController.add('Erro no pull: $e');
      rethrow;
    }
  }

  Task? _taskFromServer(Map data) {
    try {
      DateTime parseTime(dynamic value) {
        if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
        if (value is String) {
          return DateTime.tryParse(value) ?? DateTime.now();
        }
        return DateTime.now();
      }

      final serverId = data['id']?.toString();

      return Task(
        id: (data['id'] is num) ? (data['id'] as num).toInt() : int.tryParse('${data['id']}'),
        remoteId: serverId,
        title: (data['title'] as String?) ?? '',
        description: (data['description'] as String?) ?? '',
        priority: (data['priority'] as String?) ?? 'medium',
        completed: (data['completed'] as bool?) ?? false,
        categoryId: (data['category'] as String?) ?? 'uncategorized',
        createdAt: parseTime(data['createdAt']),
        updatedAt: parseTime(data['updatedAt']),
        version: (data['version'] as num?)?.toInt() ?? 1,
        syncStatus: 'synced',
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _taskToPayload(Task task) {
    final id = task.remoteId ?? (task.id?.toString() ?? '');
    return {
      'id': id.isNotEmpty ? id : null,
      'title': task.title,
      'description': task.description,
      'priority': task.priority,
      'completed': task.completed,
      'category': task.categoryId,
      'createdAt': task.createdAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'version': task.version,
    };
  }

  Future<Task?> _pushCreate(Task task) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tasks');
    _log('Push CREATE $uri');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_taskToPayload(task)),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final serverTask = _taskFromServer(body['task'] as Map? ?? {});
        if (serverTask != null) {
          // preserva id local e remoteId do servidor
          return serverTask.copyWith(id: task.id ?? serverTask.id);
        }
        return task;
      } catch (_) {
        return task;
      }
    } else {
      throw Exception('Erro ao criar no servidor: ${response.statusCode}');
    }
  }

  Future<Task?> _pushUpdate(Task task) async {
    final serverId = task.remoteId ?? task.id?.toString() ?? '';
    final uri = Uri.parse('${ApiConfig.baseUrl}/tasks/$serverId');
    _log('Push UPDATE $uri');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_taskToPayload(task)),
    );
    if (response.statusCode == 409) {
      // Conflito: aplicar LWW
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final serverTask = _taskFromServer(body['serverTask'] as Map? ?? {});
        if (serverTask != null) {
          final serverTime = serverTask.updatedAt.millisecondsSinceEpoch;
          final localTime = task.updatedAt.millisecondsSinceEpoch;
          if (localTime > serverTime || task.version > serverTask.version) {
            // Local vence: reenviar usando versão do servidor
            final payload = _taskToPayload(task.copyWith(version: serverTask.version));
            final retry = await http.put(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );
            if (retry.statusCode >= 200 && retry.statusCode < 300) {
              _syncMessageController.add('Conflito resolvido: local venceu (id=$serverId)');
              return task.copyWith(version: serverTask.version + 1);
            }
          } else {
            // Servidor vence: atualizar local
            await _markSynced(serverTask);
            _syncMessageController.add('Conflito resolvido: servidor venceu (id=$serverId)');
            return serverTask;
          }
        }
      } catch (_) {
        // cai no erro abaixo
      }
      throw Exception('CONFLICT');
    }
    if (response.statusCode == 404) {
      // Registro inexistente no servidor: tenta recriar para convergência
      try {
        _log('UPDATE retornou 404; tentando CREATE para id=$serverId');
        final created = await _pushCreate(task);
        _syncMessageController.add('Registro ausente no servidor, recriado (id=$serverId)');
        return created ?? task;
      } catch (_) {
        // Falha na criação, deixa erro propagar
      }
      throw Exception('NOT_FOUND');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final serverTask = _taskFromServer(body['task'] as Map? ?? {});
        return serverTask ?? task;
      } catch (_) {
        return task;
      }
    } else {
      throw Exception('Erro ao atualizar no servidor: ${response.statusCode}');
    }
  }

  Future<void> _pushDelete(Task task) async {
    final id = task.remoteId ?? task.id?.toString() ?? '';
    final uri = Uri.parse('${ApiConfig.baseUrl}/tasks/$id');
    _log('Push DELETE $uri');
    final response = await http.delete(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // ok
    } else if (response.statusCode == 404) {
      // já não existe no servidor, ok
    } else {
      throw Exception('Erro ao deletar no servidor: ${response.statusCode}');
    }
  }

  // Persistência simples do lastSync em arquivo local
  Future<int> _readLastSyncTimestamp() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'last_sync.txt'));
      if (await file.exists()) {
        final content = await file.readAsString();
        return int.tryParse(content) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _writeLastSyncTimestamp(int timestamp) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'last_sync.txt'));
      await file.writeAsString('$timestamp');
    } catch (_) {}
  }

  Future<void> _markSynced(Task task) async {
    await DatabaseService.instance.update(task.copyWith(syncStatus: 'synced'));
  }

  void _log(String message) {
    // You can replace this with any logging mechanism you prefer
    print('[SyncService] $message');
  }
}
