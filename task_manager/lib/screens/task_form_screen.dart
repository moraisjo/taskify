import 'dart:io';

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../widgets/location_picker.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task; // null = criar novo, não-null = editar

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  String _categoryId = 'uncategorized';
  bool _completed = false;
  bool _isLoading = false;
  String? _photoPath;
  double? _latitude;
  double? _longitude;
  String? _locationName;

  @override
  void initState() {
    super.initState();

    // Se estiver editando, preencher campos
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _categoryId = widget.task!.categoryId;
      _completed = widget.task!.completed;
      _photoPath = widget.task!.photoPath;
      _latitude = widget.task!.latitude;
      _longitude = widget.task!.longitude;
      _locationName = widget.task!.locationName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.task == null) {
        // Criar nova tarefa
        final newTask = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          categoryId: _categoryId,
          completed: _completed,
          completedAt: _completed ? DateTime.now() : null,
          completedBy: _completed ? 'manual' : null,
          photoPath: _photoPath,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
        );
        await DatabaseService.instance.create(newTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa criada com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Atualizar tarefa existente
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          categoryId: _categoryId,
          completed: _completed,
          completedAt: _completed ? (widget.task!.completedAt ?? DateTime.now()) : null,
          completedBy: _completed ? (widget.task!.completedBy ?? 'manual') : null,
          photoPath: _photoPath,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
        );
        await DatabaseService.instance.update(updatedTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa atualizada com sucesso'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // CÂMERA METHODS
  Future<void> _takePicture() async {
    final photoPath = await CameraService.instance.takePicture(context);
    if (photoPath != null && mounted) {
      setState(() => _photoPath = photoPath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Foto capturada!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removePhoto() {
    setState(() => _photoPath = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto removida')));
  }

  void _viewPhoto() {
    if (_photoPath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(_photoPath!), fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  // GPS METHODS
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: LocationPicker(
            initialLatitude: _latitude,
            initialLongitude: _longitude,
            initialAddress: _locationName,
            onLocationSelected: (lat, lon, address) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
                _locationName = address;
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('📋 Localização removida')));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo de Título
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ex: Estudar Flutter',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, digite um título';
                        }
                        if (value.trim().length < 3) {
                          return 'Título deve ter pelo menos 3 caracteres';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),

                    const SizedBox(height: 16),

                    // Dropdown de Categoria
                    DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: Category.presets
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: cat.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(cat.name),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _categoryId = value);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Campo de Descrição
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Adicione mais detalhes...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 5,
                      maxLength: 500,
                    ),

                    const SizedBox(height: 16),

                    // Dropdown de Prioridade
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Baixa'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Média'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Alta'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Urgente'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _priority = value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Switch de Completo
                    Card(
                      child: SwitchListTile(
                        title: const Text('Tarefa Completa'),
                        subtitle: Text(
                          _completed
                              ? 'Esta tarefa está marcada como concluída'
                              : 'Esta tarefa ainda não foi concluída',
                        ),
                        value: _completed,
                        onChanged: (value) {
                          setState(() => _completed = value);
                        },
                        secondary: Icon(
                          _completed ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _completed ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Seção Foto
                    Row(
                      children: [
                        const Icon(Icons.photo_camera, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Foto',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_photoPath != null)
                          TextButton.icon(
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_photoPath != null)
                      GestureDetector(
                        onTap: _viewPhoto,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_photoPath!),
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _takePicture,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tirar Foto'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),

                    const Divider(height: 32),

                    // Seção Localização
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Localização',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_latitude != null)
                          TextButton.icon(
                            onPressed: _removeLocation,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_latitude != null && _longitude != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: Text(_locationName ?? 'Localização salva'),
                          subtitle: Text(
                            LocationService.instance.formatCoordinates(_latitude!, _longitude!),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _showLocationPicker,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _showLocationPicker,
                        icon: const Icon(Icons.add_location),
                        label: const Text('Adicionar Localização'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),

                    const SizedBox(height: 32),

                    // Botão Salvar
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveTask,
                      icon: const Icon(Icons.save),
                      label: Text(isEditing ? 'Atualizar Tarefa' : 'Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Botão Cancelar
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
