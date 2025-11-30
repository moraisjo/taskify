class Task {
  final int? id;
  final String? remoteId;
  final String title;
  final String description;
  final String priority;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String syncStatus;
  final String categoryId;
  final String? photoPath;
  final DateTime? completedAt;
  final String? completedBy;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  Task({
    this.id,
    this.remoteId,
    required this.title,
    required this.description,
    required this.priority,
    this.completed = false,
    this.categoryId = 'uncategorized',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.syncStatus = 'synced', // synced | pending | failed
    this.photoPath,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remoteId': remoteId,
      'title': title,
      'description': description,
      'priority': priority,
      'completed': completed ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
      'syncStatus': syncStatus,
      'category': categoryId,
      'photoPath': photoPath,
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: (map['id'] as num?)?.toInt(),
      remoteId: map['remoteId'] as String?,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      priority: (map['priority'] as String?) ?? 'medium',
      completed: (map['completed'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      version: (map['version'] as num?)?.toInt() ?? 1,
      syncStatus: (map['syncStatus'] as String?) ?? 'synced',
      categoryId: (map['category'] as String?)?.isNotEmpty == true ? map['category'] as String : 'uncategorized',
      photoPath: map['photoPath'] as String?,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      completedBy: map['completedBy'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationName: map['locationName'] as String?,
    );
  }

  Task copyWith({
    int? id,
    String? remoteId,
    String? title,
    String? description,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    String? syncStatus,
    String? categoryId,
    String? photoPath,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return Task(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      categoryId: categoryId ?? this.categoryId,
      photoPath: photoPath ?? this.photoPath,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
    );
  }
}
