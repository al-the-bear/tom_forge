/// Sample workspace files for the test IDE.
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
};

const _readme = '''
# Sample Project

A demonstration workspace for the Forge Test IDE.

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
description: A sample project for the Forge IDE.
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

int clamp(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

List<String> splitLines(String text) {
  return text.split('\\n');
}
''';

const _appTest = '''
import 'package:test/test.dart';
import '../lib/src/app.dart';
import '../lib/src/utils.dart';

void main() {
  group('App', () {
    test('describe returns correct string', () {
      final app = App(name: 'Test');
      expect(app.describe(), equals('App(Test)'));
    });

    test('getVersion returns semver', () {
      expect(getVersion(), matches(RegExp(r'^\\d+\\.\\d+\\.\\d+\$')));
    });
  });

  group('Utils', () {
    test('formatGreeting with name', () {
      expect(formatGreeting('Alice'), equals('Hello, Alice!'));
    });

    test('formatGreeting empty', () {
      expect(formatGreeting(''), equals('Hello, World!'));
    });

    test('clamp within range', () {
      expect(clamp(5, 0, 10), equals(5));
    });

    test('clamp below min', () {
      expect(clamp(-1, 0, 10), equals(0));
    });
  });
}
''';

const _architectureMd = '''
# Architecture

## Overview

The sample project follows a simple layered architecture.

## Layers

### Entry Point (`main.dart`)

Bootstraps the application and delegates to `App`.

### Application (`app.dart`)

Core business logic and orchestration.

### Utilities (`utils.dart`)

Pure functions with no side effects.

## Testing Strategy

Unit tests cover all public API surfaces.
Each utility function has at least one positive and one edge-case test.
''';
