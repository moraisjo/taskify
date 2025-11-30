import 'dart:async';

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/sensor_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class TaskListScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const TaskListScreen({super.key, required this.themeMode, required this.onToggleTheme});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  String _filter = 'all'; // all, completed, pending
  String _searchQuery = '';
  String _categoryFilter = 'all';
  bool _isLoading = true;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<bool>? _syncSubscription;
  StreamSubscription<String>? _syncMessageSubscription;

  @override
  void initState() {
    super.initState();
    // Inicializa sync (ele mesmo escuta conectividade) e apenas assinamos o stream para UI
    SyncService.instance.initialize();
    _connectivitySubscription = ConnectivityService.instance.onlineStream.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
    _syncSubscription = SyncService.instance.onSyncComplete.listen((_) {
      if (!mounted) return;
      _loadTasks();
    });
    _syncMessageSubscription = SyncService.instance.onSyncMessage.listen(_handleSyncMessage);
    _loadTasks();
    _setupShakeDetection();
  }

  @override
  void dispose() {
    SensorService.instance.stop();
    _connectivitySubscription?.cancel();
    _syncSubscription?.cancel();
    _syncMessageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await DatabaseService.instance.readAll();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar tarefas: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupShakeDetection() {
    SensorService.instance.startShakeDetection(() {
      if (!mounted) return;
      _showShakeDialog();
    });
  }

  void _showShakeDialog() {
    final pendingTasks = _tasks.where((t) => !t.completed).toList();
    if (pendingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📋 Nenhuma tarefa pendente!'), backgroundColor: Colors.green),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vibration, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Shake detectado!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecione uma tarefa para completar:'),
            const SizedBox(height: 16),
            ...pendingTasks
                .take(3)
                .map(
                  (task) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _completeTaskByShake(task),
                    ),
                  ),
                ),
            if (pendingTasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${pendingTasks.length - 3} outras',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  Future<void> _completeTaskByShake(Task task) async {
    try {
      final updated = task.copyWith(
        completed: true,
        completedAt: DateTime.now(),
        completedBy: 'shake',
      );
      await DatabaseService.instance.update(updated);
      if (mounted) Navigator.pop(context);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${task.title}" completa via shake!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  List<Task> get _filteredTasks {
    var tasks = _tasks;

    // Filtro por status
    switch (_filter) {
      case 'completed':
        tasks = tasks.where((t) => t.completed).toList();
        break;
      case 'pending':
        tasks = tasks.where((t) => !t.completed).toList();
        break;
    }

    // Filtro por busca
    if (_searchQuery.isNotEmpty) {
      tasks = tasks
          .where(
            (t) =>
                t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.description.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    if (_categoryFilter != 'all') {
      tasks = tasks.where((t) => t.categoryId == _categoryFilter).toList();
    }

    return tasks;
  }

  Future<void> _toggleTask(Task task) async {
    try {
      final bool newCompleted = !task.completed;
      final updated = task.copyWith(
        completed: newCompleted,
        completedAt: newCompleted ? DateTime.now() : null,
        completedBy: newCompleted ? 'manual' : null,
        syncStatus: 'pending',
      );
      // Atualiza lista local para refletir no filtro atual imediatamente
      setState(() {
        _tasks = _tasks.map((t) => t.id == task.id ? updated : t).toList();
      });
      await DatabaseService.instance.update(updated);
      await DatabaseService.instance.addToSyncQueue(operation: 'UPDATE', task: updated);
      if (ConnectivityService.instance.isOnline) {
        await SyncService.instance.sync();
      }
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar tarefa: $e')));
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    // Confirmar exclusão
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Enfileira delete antes da remoção local
        final payloadTask = task.copyWith(syncStatus: 'pending');
        await DatabaseService.instance.addToSyncQueue(operation: 'DELETE', task: payloadTask);
        if (ConnectivityService.instance.isOnline) {
          await SyncService.instance.sync();
        }

        // Remove local imediatamente
        await DatabaseService.instance.delete(task.id);
        await _loadTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarefa excluída'), duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao excluir tarefa: $e')));
        }
      }
    }
  }

  Future<void> _openTaskForm([Task? task]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskFormScreen(task: task)),
    );

    if (result == true) {
      await _loadTasks();
    }
  }

  Future<void> _exportTasks() async {
    try {
      final file = await DatabaseService.instance.exportToJson();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exportado para: ${file.path}')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
      }
    }
  }

  Future<void> _importTasks() async {
    try {
      final imported = await DatabaseService.instance.importFromJson();
      if (!mounted) return;
      await _loadTasks();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Importação concluída: $imported itens')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao importar: $e')));
      }
    }
  }

  Future<void> _manualSync() async {
    if (!_isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline: não foi possível sincronizar agora')),
        );
      }
      return;
    }
    try {
      await SyncService.instance.sync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronização iniciada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao sincronizar: $e')),
        );
      }
    }
  }

  void _setFilter(String value) {
    setState(() => _filter = value);
    _loadTasks();
  }

  void _setCategory(String value) {
    setState(() => _categoryFilter = value);
    _loadTasks();
  }

  void _handleSyncMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;
    final stats = _calculateStats();
    final isDark =
        widget.themeMode == ThemeMode.dark ||
        (widget.themeMode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);
    final categories = Category.presets;
    final statusColor = _isOnline ? Colors.green : Colors.orange;
    final statusText = _isOnline ? 'Online' : 'Offline';
    final statusIcon = _isOnline ? Icons.cloud_done : Icons.cloud_off;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Tema claro' : 'Tema escuro',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Sincronizar agora',
            onPressed: _manualSync,
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Recarregar', onPressed: _loadTasks),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar JSON',
            onPressed: _exportTasks,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Importar JSON',
            onPressed: _importTasks,
          ),
          // Filtro
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => _setFilter(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(children: [Icon(Icons.list), SizedBox(width: 8), Text('Todas')]),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [Icon(Icons.pending_actions), SizedBox(width: 8), Text('Pendentes')],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [Icon(Icons.check_circle), SizedBox(width: 8), Text('Concluídas')],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Barra de Busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar tarefas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Filtro por categoria
          if (_tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _categoryFilter == 'all',
                      onSelected: (_) => _setCategory('all'),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: _categoryFilter == cat.id,
                          selectedColor: cat.color.withValues(alpha: 0.2),
                          onSelected: (_) => _setCategory(cat.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Card de Estatísticas
          if (_tasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.list,
                    label: 'Total',
                    value: stats['total'].toString(),
                    selected: _filter == 'all',
                    onTap: () => _setFilter('all'),
                  ),
                  _buildStatItem(
                    icon: Icons.pending_actions,
                    label: 'Pendentes',
                    value: stats['pending'].toString(),
                    selected: _filter == 'pending',
                    onTap: () => _setFilter('pending'),
                  ),
                  _buildStatItem(
                    icon: Icons.check_circle,
                    label: 'Concluídas',
                    value: stats['completed'].toString(),
                    selected: _filter == 'completed',
                    onTap: () => _setFilter('completed'),
                  ),
                ],
              ),
            ),

          // Lista de Tarefas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTasks.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 300),
                            child: SlideAnimation(
                              verticalOffset: 16,
                              child: FadeInAnimation(
                                child: TaskCard(
                                  task: task,
                                  onTap: () => _openTaskForm(task),
                                  onToggle: () => _toggleTask(task),
                                  onDelete: () => _deleteTask(task),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filter) {
      case 'completed':
        message = 'Nenhuma tarefa concluída ainda';
        icon = Icons.check_circle_outline;
        break;
      case 'pending':
        message = 'Nenhuma tarefa pendente';
        icon = Icons.pending_actions;
        break;
      default:
        message = 'Nenhuma tarefa cadastrada';
        icon = Icons.task_alt;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openTaskForm(),
            icon: const Icon(Icons.add),
            label: const Text('Criar primeira tarefa'),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    return {
      'total': _tasks.length,
      'completed': _tasks.where((t) => t.completed).length,
      'pending': _tasks.where((t) => !t.completed).length,
    };
  }
}
