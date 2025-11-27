# Gerenciador de Tarefas

Este projeto Flutter é um aplicativo local de gerenciamento de tarefas construído com SQLite para persistência de dados. Ele permite criar, atualizar, concluir e excluir tarefas em uma interface simples. O app demonstra conceitos fundamentais de Flutter, como widgets com estado, camada de serviços para acesso ao banco e separação entre modelo e visualização. Entre os recursos estão priorização de tarefas, filtro por status e contadores de tarefas.

## Requisitos
- Flutter SDK (>=3.9.0 <4.0.0)
- Emulador ou dispositivo físico (Android/iOS/Web/Desktop)

## Dependências Principais
- Flutter framework
- sqflite 2.3.0
- path_provider 2.1.1
- path 1.8.3
- uuid 4.2.1
- intl 0.19.0

## Estrutura de Pastas
```text
task_manager/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── task.dart
│   ├── screens/
│   │   ├── task_form_screen.dart
│   │   └── task_list_screen.dart
│   ├── services/
│   │   └── database_service.dart
│   └── widgets/
│       └── task_card.dart
├── test/
│   └── widget_test.dart
├── pubspec.yaml
└── README.md
```

## Executar Localmente
```bash
flutter pub get
flutter run
```

Limpeza opcional: `flutter clean` remove artefatos de build caso você troque de alvo ou enfrente problemas de cache.

## Relatório - Laboratório 2: Interface Profissional

### 1. Implementações Realizadas
- Persistência local com SQLite (sqflite + sqflite_common_ffi) e serviços dedicados para CRUD de tarefas.
- Tela principal com estatísticas, filtros de status e lista responsiva de tarefas com suporte a atualização pull-to-refresh.
- Formulário de criação/edição com validação de campos, seleção de prioridade e controle de conclusão.
- Feedbacks visuais via SnackBar e confirmação de exclusão com AlertDialog.
- Modo tela claro/escuro com botão canto superior
- Transição entre as estatísticas

### Componentes Material Design 3 Utilizados
- `Scaffold`, `AppBar` e `FloatingActionButton.extended`.
- `Card`, `ListView`, `RefreshIndicator` e `InkWell` para exibir tarefas.
- `TextFormField`, `DropdownButtonFormField`, `SwitchListTile`, `ElevatedButton` e `OutlinedButton` no formulário.
- `Checkbox`, `PopupMenuButton`, `SnackBar` e `AlertDialog` para interação e feedback.
