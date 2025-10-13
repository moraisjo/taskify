import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  final _titleController = TextEditingController();
  final List<String> _priorities = const ['low', 'medium', 'high'];
  String _selectedPriority = 'medium';
  TaskFilter _filter = TaskFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await DatabaseService.instance.readAll();
    setState(() => _tasks = _applyFilter(tasks));
  }

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final task = Task(
      title: _titleController.text.trim(),
      priority: _selectedPriority,
    );
    await DatabaseService.instance.create(task);
    _titleController.clear();
    setState(() => _selectedPriority = 'medium');
    _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    _loadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await DatabaseService.instance.delete(id);
    _loadTasks();
  }

  List<Task> _applyFilter(List<Task> tasks) {
    switch (_filter) {
      case TaskFilter.completed:
        return tasks.where((task) => task.completed).toList();
      case TaskFilter.pending:
        return tasks.where((task) => !task.completed).toList();
      case TaskFilter.all:
      default:
        return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Nova tarefa...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedPriority,
                  items: _priorities
                      .map((priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedPriority = value);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Adicionar'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ToggleButtons(
              isSelected: TaskFilter.values
                  .map((filter) => filter == _filter)
                  .toList(),
              onPressed: (index) {
                final selected = TaskFilter.values[index];
                if (selected == _filter) return;
                setState(() => _filter = selected);
                _loadTasks();
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Todas'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Completas'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Pendentes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return ListTile(
                  leading: Checkbox(
                    value: task.completed,
                    onChanged: (_) => _toggleTask(task),
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text('Prioridade: ${task.priority.toUpperCase()}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTask(task.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum TaskFilter { all, completed, pending }
