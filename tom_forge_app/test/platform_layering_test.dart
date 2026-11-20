// REPO-WIDE GUARD (tom_forge_app) — every package in tom_forge sits in its
// layer of the platform architecture and depends only downwards.
//
// The layers, their contracts and the rules are
// `tom_forge/_agent_guidelines/platform_architecture.md` §1 and §3; the
// table below is that document's table. A package the table does not know
// fails PL-1, so a new package is placed on purpose, not by accident.
//
// It reads each package's `pubspec.yaml` (dependencies and dev
// dependencies), not its imports: a dependency is what lets an import
// compile, so a layer violation cannot exist without one. It lives here
// because tom_forge_app composes the whole suite and is `publish_to: none`;
// it skips when the repo root is not reachable.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer of every package in the repository
/// (`platform_architecture.md` §1).
const Map<String, int> _layers = <String, int>{
  // 0 Foundation: pure Dart.
  'tom_forge_core': 0,
  'tom_website_editor_core': 0,
  'tom_dart_editor_bundler': 0,
  'tom_web_build_probe': 0,
  // 1 Editor kit and the shared look.
  'tom_editors_shared': 1,
  'tom_forge_shared_ui': 1,
  // 2 Editors: usable without the shell.
  'tom_md_editor': 2,
  'tom_yaml_editor': 2,
  'tom_dart_editor': 2,
  'tom_flow_editor': 2,
  // 3 Shell core.
  'tom_forge_shell': 3,
  // 4 Shell parts: what plugs into the core (ForgeShellComponents).
  'tom_forge_terminal': 4,
  'tom_forge_code_editors': 4,
  'tom_forge_platform_secrets': 4,
  'tom_forge_desktop_host': 4,
  // 4 Test support (see _testSupport).
  'tom_forge_ui_testing': 4,
  // 5 The shell with its parts (the umbrella).
  'tom_forge_ui': 5,
  // 6 Shell services.
  'tom_forge_agentic': 6,
  // 7 Modules.
  'tom_forge_file_editors': 7,
  'tom_forge_office_editors': 7,
  'tom_forge_pdf_editors': 7,
  'tom_forge_quests': 7,
  'tom_website_editor': 7,
  'tom_specs_editor': 7,
  // 8 Module test support (see _testSupport).
  'tom_forge_file_editors_testing': 8,
  'tom_forge_office_editors_testing': 8,
  'tom_forge_pdf_editors_testing': 8,
  // 9 Apps.
  'tom_forge_app': 9,
};

/// Test support: packages built on `flutter_test` for other packages'
/// suites. Any package may take one as a dev_dependency, also a lower one
/// (`tom_forge_ui`'s suites run the harness built on `tom_forge_ui`); as a
/// dependency they follow the layers like every other package.
const Set<String> _testSupport = <String>{
  'tom_forge_ui_testing',
  'tom_forge_file_editors_testing',
  'tom_forge_office_editors_testing',
  'tom_forge_pdf_editors_testing',
};

/// Companion apps and test beds: they depend on anything below the apps, and
/// nothing depends on them.
const Set<String> _harness = <String>{
  'tom_dart_editor_test',
  'tom_flow_editor_test',
  'tom_forge_ui_test',
  'tom_md_editor_test',
  'tom_yaml_editor_test',
  'tom_wpe_webview_test',
};

/// Packages from Webwork's repository a Forge package may depend on, each
/// with why it does not bring Webwork in. AN ENTRY IS A LICENCE CLAIM: only a
/// BSD-3 package that depends on no Webwork application package belongs
/// here. PL-5 fails once an entry is no longer used.
const Map<String, String> _webworkRepoPackagesAllowed = <String, String>{};

class _Dependency {
  const _Dependency(this.name, this.path, {required this.dev});
  final String name;

  /// The `path:` of a path dependency, else null.
  final String? path;
  final bool dev;
}

class _Package {
  _Package(this.name, this.dir, this.dependencies);
  final String name;
  final Directory dir;
  final List<_Dependency> dependencies;

  bool dependsOnFlutter() => dependencies.any((d) => d.name == 'flutter');
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

/// The `dependencies` and `dev_dependencies` of a pubspec, read by
/// indentation (the shape `pub` itself writes and the workspace keeps).
List<_Dependency> _dependenciesOf(File pubspec) {
  final out = <_Dependency>[];
  String? section;
  String? open;
  String? openPath;
  void flush() {
    if (open != null) {
      out.add(_Dependency(open!, openPath, dev: section == 'dev_dependencies'));
    }
    open = openPath = null;
  }

  for (final raw in pubspec.readAsLinesSync()) {
    final line = raw.split('#').first.trimRight();
    if (line.trim().isEmpty) continue;
    if (!line.startsWith(' ')) {
      flush();
      section = line.endsWith(':') ? line.substring(0, line.length - 1) : null;
      continue;
    }
    if (section != 'dependencies' && section != 'dev_dependencies') continue;
    final key = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (key != null) {
      flush();
      open = key.group(1);
      continue;
    }
    final path = RegExp(r'^\s{4,}path:\s*(\S+)').firstMatch(line);
    if (path != null && open != null) openPath = path.group(1);
  }
  flush();
  return out;
}

/// Every top-level package of the repository, by name.
Map<String, _Package> _packages(Directory root) {
  final out = <String, _Package>{};
  for (final dir in root.listSync().whereType<Directory>()) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final name = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())!.group(1)!;
    out[name] = _Package(name, dir, _dependenciesOf(pubspec));
  }
  return out;
}

bool _isWebworkRepoPath(String path) =>
    path.replaceAll(r'\', '/').contains('app_webwork/');

void main() {
  final root = _repoRoot();
  final packages = root == null ? <String, _Package>{} : _packages(root);

  bool reachable() {
    if (root != null) return true;
    markTestSkipped('tom_forge repo root not reachable — nothing to check');
    return false;
  }

  group('platform layering (tom_forge)', () {
    test(
      'PL-1: every package has a layer, and every layer entry a package',
      () {
        if (!reachable()) return;
        final known = {..._layers.keys, ..._harness};
        expect(
          packages.keys.toSet().difference(known),
          isEmpty,
          reason:
              'Not in the layer table: give each a layer in '
              'platform_architecture.md §1 and in _layers here.',
        );
        expect(
          known.difference(packages.keys.toSet()),
          isEmpty,
          reason: 'In the layer table but not in the repository: delete them.',
        );
      },
    );

    test('PL-2: every dependency between Forge packages points down', () {
      if (!reachable()) return;
      final offenders = <String>[];
      for (final package in packages.values) {
        for (final dep in package.dependencies) {
          if (!packages.containsKey(dep.name)) continue;
          final from = package.name, to = dep.name;
          bool placed(String n) =>
              _layers.containsKey(n) || _harness.contains(n);
          // An unplaced package is PL-1's finding, not a layering one.
          if (!placed(from) || !placed(to)) continue;
          final kind = dep.dev ? 'dev_dependency' : 'dependency';
          if (dep.dev && _testSupport.contains(to)) continue;
          if (_harness.contains(to)) {
            offenders.add('$from has a $kind on the harness package $to');
          } else if (_harness.contains(from)) {
            if (_layers[to] == 9) {
              offenders.add('harness $from has a $kind on the app $to');
            }
          } else if (_layers[to]! >= _layers[from]!) {
            offenders.add(
              '$from (layer ${_layers[from]}) has a $kind on $to '
              '(layer ${_layers[to]})',
            );
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A package depends only on lower layers '
            '(platform_architecture.md §1). Move the shared part down, or '
            'the package up — never the arrow.\n${offenders.join('\n')}',
      );
    });

    test('PL-3: the foundation is pure Dart', () {
      if (!reachable()) return;
      final flutter = [
        for (final entry in _layers.entries)
          if (entry.value == 0 &&
              (packages[entry.key]?.dependsOnFlutter() ?? false))
            entry.key,
      ];
      expect(
        flutter,
        isEmpty,
        reason:
            'Layer 0 is usable by a headless tool and a test without '
            'Flutter.',
      );
    });

    test('PL-4: no Forge package depends on Webwork', () {
      if (!reachable()) return;
      final offenders = <String>[];
      for (final package in packages.values) {
        for (final dep in package.dependencies) {
          final fromWebworkRepo =
              dep.path != null && _isWebworkRepoPath(dep.path!);
          final webworkName = dep.name.startsWith('tom_webwork');
          if ((fromWebworkRepo || webworkName) &&
              !_webworkRepoPackagesAllowed.containsKey(dep.name)) {
            offenders.add('${package.name} depends on ${dep.name}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Webwork joins Forge only through Forge\'s extension points '
            '(ForgeSuiteExtension), never as a dependency: Forge is the '
            'platform and Webwork an application on it.\n'
            '${offenders.join('\n')}',
      );
    });

    test('PL-5: every allowed Webwork-repository package is still used', () {
      if (!reachable()) return;
      final used = {
        for (final package in packages.values)
          for (final dep in package.dependencies)
            if (dep.path != null && _isWebworkRepoPath(dep.path!)) dep.name,
      };
      expect(
        _webworkRepoPackagesAllowed.keys.toSet().difference(used),
        isEmpty,
        reason: 'No longer used: delete the entry.',
      );
    });

    test('PL-6: the shared look takes Flutter, tom_ui_support and at most '
        'tom_forge_core', () {
      if (!reachable()) return;
      final shared = packages['tom_forge_shared_ui'];
      expect(shared, isNotNull);
      const allowed = {
        'flutter',
        'tom_ui_support',
        'tom_forge_core',
        'flutter_test',
        'flutter_lints',
      };
      expect(
        shared!.dependencies.map((d) => d.name).toSet().difference(allowed),
        isEmpty,
        reason:
            'tom_forge_shared_ui is what Webwork takes for Forge\'s look: no '
            'terminal, no editors, no webview, no native plugin.',
      );
    });
  });
}
