import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final Color color;

  const Category({required this.id, required this.name, required this.color});

  static const List<Category> presets = [
    Category(id: 'uncategorized', name: 'Sem categoria', color: Colors.grey),
    Category(id: 'general', name: 'Geral', color: Colors.blueGrey),
    Category(id: 'work', name: 'Trabalho', color: Colors.blue),
    Category(id: 'study', name: 'Estudos', color: Colors.deepPurple),
    Category(id: 'personal', name: 'Pessoal', color: Colors.teal),
  ];

  static Category resolve(String? id) {
    if (id == null || id.isEmpty) return presets.first;
    return presets.firstWhere(
      (c) => c.id == id,
      orElse: () => presets.first,
    );
  }
}
