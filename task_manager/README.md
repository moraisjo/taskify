# Task Manager

Simple Flutter prototype that stores tasks in SQLite with priority selection, status filtering, and task counters.

## Requirements
- Flutter SDK (>=3.9.0 <4.0.0)
- Emulator or physical device (Android/iOS/Web/Desktop)

## Key Dependencies
- Flutter framework
- sqflite 2.3.0
- path_provider 2.1.1
- path 1.8.3
- uuid 4.2.1
- intl 0.19.0

## Folder Structure
```text
task_manager/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── task.dart
│   ├── screens/
│   │   └── task_list_screen.dart
│   └── services/
│       └── database_service.dart
├── test/
│   └── widget_test.dart
├── pubspec.yaml
└── README.md
```

## Run Locally
```bash
flutter pub get
flutter run
```

Optional housekeeping: `flutter clean` resets build artefacts if you switch targets or hit caching issues.
