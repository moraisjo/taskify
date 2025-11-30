# Task Manager Offline-First

Aplicativo Flutter com persistência local (SQLite) e sincronização eventual com backend Node/Express. Suporta criação/edição/exclusão offline, fila de sync, resolução LWW e indicador de conectividade.

## Requisitos
- Flutter SDK (>=3.9.0 <4.0.0)
- Node.js 18+ e npm
- Emulador/dispositivo Android ou desktop/web

## Principais dependências
### Flutter
- sqflite, sqflite_common_ffi, path_provider, path
- connectivity_plus, http, intl
- flutter_staggered_animations

### Backend (npm)
- express, cors, body-parser, uuid

## Estrutura de pastas
```text
task_manager/
├── lib/
│   ├── main.dart
│   ├── models/ (task.dart, category.dart)
│   ├── services/ (database_service.dart, sync_service.dart, connectivity_service.dart, api_config.dart, camera_service.dart, location_service.dart, sensor_service.dart)
│   ├── screens/ (task_list_screen.dart, task_form_screen.dart)
│   └── widgets/ (task_card.dart, location_picker.dart)
├── server/ (server.js, storage.js, package.json, package-lock.json)
├── android/ios/macos/windows/linux/web/ (projetos Flutter nativos)
├── pubspec.yaml
└── README.md
```

## Como rodar
1) Backend Node  
```bash
cd server
npm install
npm start   # inicia em http://localhost:3000
```

2) App Flutter  
- Desktop/web: usa `http://localhost:3000/api` por padrão.  
- Emulador Android: rodar com `--dart-define API_BASE_URL=http://10.0.2.2:3000/api`.  
- Device físico: `--dart-define API_BASE_URL=http://<IP-da-sua-máquina>:3000/api`.

Comandos:
```bash
flutter pub get
flutter run --dart-define API_BASE_URL=http://10.0.2.2:3000/api   # ajuste host conforme o alvo
```

## Notas de sincronização
- Operações locais gravam no SQLite e entram na `sync_queue` com status pending/failed.
- O SyncService envia a fila quando online, aplica LWW e trata 404 de update recriando a tarefa.
- Indicadores na UI mostram pendente/sincronizado e estado online/offline.
