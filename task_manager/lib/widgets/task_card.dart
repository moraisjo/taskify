import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/category.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Function(bool?)? onCheckboxChanged;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.onCheckboxChanged,
  });

  Color _getPriorityColor() {
    switch (task.priority) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'urgent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon() {
    switch (task.priority) {
      case 'urgent':
        return Icons.priority_high;
      default:
        return Icons.flag;
    }
  }

  String _getPriorityLabel() {
    switch (task.priority) {
      case 'low':
        return 'Baixa';
      case 'medium':
        return 'Média';
      case 'high':
        return 'Alta';
      case 'urgent':
        return 'Urgente';
      default:
        return 'Média';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseTextColor = task.completed
        ? colorScheme.onSurface.withValues(alpha: 0.6)
        : colorScheme.onSurface;
    final secondaryTextColor = task.completed
        ? colorScheme.onSurface.withValues(alpha: 0.45)
        : colorScheme.onSurfaceVariant;
    final subtleTextColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
    final priorityColor = _getPriorityColor();
    final locationLabel = task.locationName;
    final category = Category.resolve(task.categoryId);
    final isPending = task.syncStatus != 'synced';
    final syncIcon = isPending ? Icons.cloud_off : Icons.cloud_done;
    final syncColor = isPending ? Colors.orange.shade600 : Colors.green.shade600;
    final syncLabel = isPending ? 'Pendente' : 'Sincronizado';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: task.completed ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.completed ? colorScheme.outlineVariant : priorityColor,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: task.completed,
                onChanged: onCheckboxChanged ?? (_) => onToggle(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),

              const SizedBox(width: 12),

              // Conteúdo Principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Indicador de sync pendente
                    Row(
                      children: [
                        Icon(syncIcon, size: 16, color: syncColor),
                        const SizedBox(width: 4),
                        Text(
                          syncLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: syncColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Título
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: task.completed ? TextDecoration.lineThrough : null,
                        color: baseTextColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                          decoration: task.completed ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Metadata Row
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Prioridade
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: priorityColor.withOpacity(0.1),
                            border: Border.all(color: priorityColor.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getPriorityIcon(), size: 14, color: priorityColor),
                              const SizedBox(width: 4),
                              Text(
                                _getPriorityLabel(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: priorityColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Foto
                        if (task.hasPhoto)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera, size: 14, color: Colors.blue),
                                SizedBox(width: 4),
                                Text(
                                  'Foto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Localização
                        if (task.hasLocation)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 14, color: Colors.purple),
                                SizedBox(width: 4),
                                Text(
                                  'Local',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Shake
                        if (task.completed && task.wasCompletedByShake)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.vibration, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Shake',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Data
                        Icon(Icons.access_time, size: 14, color: subtleTextColor),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(task.createdAt),
                          style: TextStyle(fontSize: 12, color: subtleTextColor),
                        ),

                        // Categoria
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: category.color.withOpacity(0.12),
                            border: Border.all(color: category.color, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label, size: 14, color: category.color),
                              const SizedBox(width: 4),
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: category.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (task.completed && task.completedAt != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade400),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(task.completedAt!),
                            style: TextStyle(fontSize: 12, color: Colors.green.shade400),
                          ),
                        ],

                        if (locationLabel != null && locationLabel.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, size: 14, color: subtleTextColor),
                          const SizedBox(width: 4),
                          Text(
                            locationLabel,
                            style: TextStyle(fontSize: 12, color: subtleTextColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Botão Deletar
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Deletar tarefa',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
