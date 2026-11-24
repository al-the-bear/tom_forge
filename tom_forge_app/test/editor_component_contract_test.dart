// REPO-WIDE GUARD (tom_forge_app) — every editor in tom_forge is placed in
// the editor component contract: a document editor runs the undo
// conformance harness, a surface extends ForgeSurfaceEditor, and every
// editor component carries its debug trail, web build check and embedding
// documentation.
//
// The contract is `tom_forge/_agent_guidelines/editor_component_contract.md`;
// the register below is its §2 table. It reads the source (class
// declarations, test files), so it needs no editor to be constructed. It
// skips when the repo root is not reachable.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every document editor (a `ForgeEditor` bound to a document), with the
/// test file that runs `runForgeUndoConformance` on it
/// (`editor_component_contract.md` §2).
const Map<String, String> _documentEditors = <String, String>{
  'ForgeMdEditor': 'tom_forge_ui/test/undo/adapters_undo_conformance_test.dart',
  'ForgeDartEditor':
      'tom_forge_ui/test/undo/adapters_undo_conformance_test.dart',
  'ForgeYamlEditor':
      'tom_forge_ui/test/undo/adapters_undo_conformance_test.dart',
  'ForgePlainTextEditor':
      'tom_forge_plain_text_editor/test/undo_conformance_test.dart',
  'ForgeMarkdownFileEditor':
      'tom_forge_md_editor/test/undo_conformance_test.dart',
  'ForgeYamlFileEditor':
      'tom_forge_yaml_editor/test/undo_conformance_test.dart',
  'ForgeEnvFileEditor':
      'tom_forge_file_editors/test/undo_conformance_test.dart',
  'ForgeTodoFileEditor':
      'tom_forge_file_editors/test/undo_conformance_test.dart',
  'WebsiteConfigEditor':
      'tom_website_editor/test/website_config_editor_undo_conformance_test.dart',
  'SpecFileEditor':
      'tom_specs_editor/test/spec_file_editor_undo_conformance_test.dart',
  'ForgePdfEditor': 'tom_forge_pdf_pdfium/test/undo_conformance_test.dart',
  'ForgePdfJsEditor': 'tom_forge_pdf_pdfjs/test/undo_conformance_test.dart',
  'ForgeOfficeEditor': 'tom_forge_office_lok/test/undo_conformance_test.dart',
  'ForgeZetaOfficeEditor':
      'tom_forge_office_zetaoffice/test/undo_conformance_test.dart',
};

/// Document editors whose conformance is another register entry's run,
/// each with why that run is its own.
const Map<String, String> _coveredBy = <String, String>{
  'SpecDocumentEditor':
      'SpecFileEditor: it adds only the file load, getContent and '
      'replaceContent; history, dirty state and views are '
      'SpecDocumentEditor\'s.',
};

/// The editor component packages (layer 2) and the one exempt from EC-4.
const List<String> _editorComponents = <String>[
  'tom_md_editor',
  'tom_yaml_editor',
  'tom_dart_editor',
  'tom_flow_editor',
];
const Map<String, String> _componentExempt = <String, String>{
  'tom_flow_editor': 'the flow editor\'s placeholder (the package template)',
};

class _Class {
  _Class(this.name, this.base, this.file, {required this.isAbstract});
  final String name;
  final String? base;
  final String file;
  final bool isAbstract;
}

Directory? _repoRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 4; i++) {
    if (File('${dir.path}/tom_repository.yaml').existsSync() &&
        Directory('${dir.path}/tom_forge_ui').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

String _rel(Directory root, File file) =>
    file.path.substring(root.path.length + 1).replaceAll(r'\', '/');

/// Every class declared under the packages' `lib/`, by name.
Map<String, _Class> _classes(Directory root) {
  final declaration = RegExp(
    r'^((?:abstract |base |final |sealed |interface )*)class (\w+)'
    r'(?:<[^>{]*>)?(?:\s+extends\s+(\w+))?',
    multiLine: true,
  );
  final out = <String, _Class>{};
  for (final package in root.listSync().whereType<Directory>()) {
    final lib = Directory('${package.path}/lib');
    if (!lib.existsSync()) continue;
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final m in declaration.allMatches(file.readAsStringSync())) {
        out[m.group(2)!] = _Class(
          m.group(2)!,
          m.group(3),
          _rel(root, file),
          isAbstract: m.group(1)!.contains('abstract'),
        );
      }
    }
  }
  return out;
}

/// The chain of bases above [name], nearest first.
List<String> _bases(Map<String, _Class> classes, String name) {
  final out = <String>[];
  var current = classes[name]?.base;
  while (current != null && !out.contains(current)) {
    out.add(current);
    current = classes[current]?.base;
  }
  return out;
}

void main() {
  final root = _repoRoot();
  final classes = root == null ? <String, _Class>{} : _classes(root);

  /// The concrete `ForgeEditor`s, by name.
  final editors = <String, _Class>{
    for (final c in classes.values)
      if (!c.isAbstract && _bases(classes, c.name).contains('ForgeEditor'))
        c.name: c,
  };
  bool isSurface(String name) =>
      _bases(classes, name).contains('ForgeSurfaceEditor');
  // The shell's test doubles live in the test-support package.
  bool isTestDouble(_Class c) => c.file.startsWith('tom_forge_ui_testing/');

  bool reachable() {
    if (root != null) return true;
    markTestSkipped('tom_forge repo root not reachable — nothing to check');
    return false;
  }

  group('editor component contract (tom_forge)', () {
    test('EC-1: every editor is a surface or a registered document editor', () {
      if (!reachable()) return;
      expect(editors, isNotEmpty, reason: 'the class scan found no editor');
      final unplaced = [
        for (final c in editors.values)
          if (!isSurface(c.name) &&
              !isTestDouble(c) &&
              !_documentEditors.containsKey(c.name) &&
              !_coveredBy.containsKey(c.name))
            '${c.name} (${c.file})',
      ];
      expect(
        unplaced,
        isEmpty,
        reason:
            'A ForgeEditor that holds no document extends '
            'ForgeSurfaceEditor; one that does runs the undo conformance '
            'harness and is registered here and in '
            'editor_component_contract.md §2.\n${unplaced.join('\n')}',
      );
    });

    test(
      'EC-2: every document editor\'s conformance run exists and makes it',
      () {
        if (!reachable()) return;
        final offenders = <String>[];
        for (final entry in _documentEditors.entries) {
          final file = File('${root!.path}/${entry.value}');
          if (!file.existsSync()) {
            offenders.add('${entry.key}: ${entry.value} does not exist');
            continue;
          }
          final text = file.readAsStringSync();
          if (!text.contains('runForgeUndoConformance(')) {
            offenders.add('${entry.key}: ${entry.value} runs no conformance');
          }
          if (!RegExp('\\b${entry.key}[.(]').hasMatch(text)) {
            offenders.add('${entry.key}: ${entry.value} never constructs it');
          }
        }
        for (final entry in _coveredBy.entries) {
          final by = entry.value.split(':').first;
          if (!_documentEditors.containsKey(by)) {
            offenders.add('${entry.key} is covered by $by, which has no run');
          }
          if (!_bases(classes, by).contains(entry.key)) {
            offenders.add(
              '${entry.key} is covered by $by, not a subclass of it',
            );
          }
        }
        expect(offenders, isEmpty, reason: offenders.join('\n'));
      },
    );

    test('EC-3: every register entry names a document editor of the repo', () {
      if (!reachable()) return;
      final stale = [
        for (final name in {..._documentEditors.keys, ..._coveredBy.keys})
          if (!editors.containsKey(name) || isSurface(name)) name,
      ];
      expect(stale, isEmpty, reason: 'Gone or now a surface: delete them.');
    });

    test('EC-4: every editor component has its debug trail, web build check '
        'and embedding documentation', () {
      if (!reachable()) return;
      final offenders = <String>[];
      final flag = RegExp(
        r'^(?:const )?bool k\w*Debug\s*=\s*false;',
        multiLine: true,
      );
      for (final package in _editorComponents) {
        if (_componentExempt.containsKey(package)) continue;
        final dir = Directory('${root!.path}/$package');
        final trails = Directory('${dir.path}/lib/src')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_trail.dart'))
            .where((f) => flag.hasMatch(f.readAsStringSync()));
        if (trails.isEmpty) {
          offenders.add(
            '$package: no *_trail.dart with a k…Debug switch, off by default',
          );
        }
        if (!File('${dir.path}/test/web_build_test.dart').existsSync()) {
          offenders.add('$package: no test/web_build_test.dart');
        }
        final readme = File('${dir.path}/README.md');
        final embedDoc = File('${dir.path}/doc/how_to_embed.md').existsSync();
        final usage =
            readme.existsSync() &&
            readme.readAsStringSync().contains(
              RegExp(r'^## Usage', multiLine: true),
            );
        if (!embedDoc && !usage) {
          offenders.add('$package: no doc/how_to_embed.md and no README Usage');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
