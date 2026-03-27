/// Sample workspace files for the Tom Forge IDE.
///
/// Keys are absolute paths; values are file contents.
const Map<String, String> workspaceSeed = {
  '/README.md': _readme,
  '/pubspec.yaml': _pubspec,
  '/lib/main.dart': _mainDart,
  '/lib/src/app.dart': _appDart,
  '/lib/src/utils.dart': _utilsDart,
  '/test/app_test.dart': _appTest,
  '/doc/architecture.md': _architectureMd,
  '/doc/notes.txt': _notesTxt,
};

const _readme = '''
# Sample Project

A demonstration workspace for the Tom Forge IDE.

## Getting Started

Run `dart run` to start the application.

## Features

- Multi-file project structure
- Markdown, Dart, and YAML files
- Unit tests with coverage

## Directory Structure

```
lib/
  main.dart       — Entry point
  src/
    app.dart      — Application widget
    utils.dart    — Utility functions
test/
  app_test.dart   — Unit tests
doc/
  architecture.md — Architecture notes
```

## License

MIT
''';

const _pubspec = '''
name: sample_project
description: A sample project for the Tom Forge IDE.
version: 1.0.0

environment:
  sdk: ^3.0.0

dependencies:
  path: ^1.8.0

dev_dependencies:
  test: ^1.24.0
''';

const _mainDart = '''
import 'src/app.dart';

void main() {
  final app = App(name: 'Sample');
  app.run();
}
''';

const _appDart = '''
import 'utils.dart';

class App {
  final String name;

  App({required this.name});

  void run() {
    final greeting = formatGreeting(name);
    print(greeting);
    print('Version: \${getVersion()}');
  }

  String describe() {
    return 'App(\$name)';
  }
}

String getVersion() => '1.0.0';
''';

const _utilsDart = '''
String formatGreeting(String name) {
  if (name.isEmpty) return 'Hello, World!';
  return 'Hello, \$name!';
}

int add(int a, int b) => a + b;

int multiply(int a, int b) => a * b;

bool isPositive(int n) => n > 0;
''';

const _appTest = '''
import 'package:test/test.dart';
import 'package:sample_project/src/app.dart';

void main() {
  group('App', () {
    test('describe returns formatted string', () {
      final app = App(name: 'Test');
      expect(app.describe(), equals('App(Test)'));
    });

    test('getVersion returns 1.0.0', () {
      expect(getVersion(), equals('1.0.0'));
    });
  });
}
''';

const _architectureMd = '''
# Architecture

## Overview

The sample project follows a simple layered architecture.

## Layers

1. **Entry Point** (`main.dart`)
   - Creates and runs the application

2. **Application** (`app.dart`)
   - Core application logic
   - Coordinates utilities

3. **Utilities** (`utils.dart`)
   - Pure helper functions
   - No external dependencies

## Testing Strategy

- Unit tests for each layer
- Integration tests for cross-layer behavior
''';

const _notesTxt = '''
Notes for the sample project.

TODO:
- Add more unit tests
- Document the API
- Set up CI/CD

DONE:
- Basic project structure
- Initial utilities
''';
