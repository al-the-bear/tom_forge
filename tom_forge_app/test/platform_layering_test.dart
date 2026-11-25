// REPO-WIDE GUARD (tom_forge_app) — every package of the platform (the
// libraries in tom_forge_modules, cloned at tom_ai/forge_modules, and the
// application's packages in tom_forge) sits in its layer of the platform
// architecture and depends only downwards.
//
// The layers, their contracts and the rules are
// `tom_ai/forge_modules/_agent_guidelines/platform_architecture.md` §1 and §3; the
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
  // 1 Editor kit.
  'tom_editors_shared': 1,
  // 2 Editors: usable without the shell; the Forge kit (layout-free, no
  // widgets): what a component sees in any application.
  'tom_forge_kit': 2,
  'tom_md_editor': 2,
  // The Markdown editor's plugin packages (see _componentPlugins).
  'tom_md_mermaid': 2,
  'tom_md_math': 2,
  'tom_md_docspecs': 2,
  'tom_md_review': 2,
  'tom_md_http': 2,
  'tom_yaml_editor': 2,
  'tom_dart_editor': 2,
  // The Dart editor's analysis plugin (see _componentPlugins).
  'tom_dart_analysis': 2,
  'tom_flow_editor': 2,
  // The terminal without Forge: a shell in a pseudo-terminal and the xterm
  // widget (see PL-10); tom_forge_terminal is its adapter.
  'tom_terminal_view': 2,
  // 3 The shared look: one rendering of the kit's models, no layout; the
  // editor adapters: the layer-2 editors as Forge editors over the kit, with
  // their editor types (see PL-8).
  'tom_forge_shared_ui': 3,
  'tom_forge_md_editor': 3,
  'tom_forge_dart_editor': 3,
  'tom_forge_yaml_editor': 3,
  // The plain-text editor: tom_file_editors' text file editor (a tom_modules
  // package) as a Forge editor over the kit; the shell falls back to it.
  'tom_forge_plain_text_editor': 3,
  // The PDF and office editor adapters, one per engine or route (R6), each
  // with its kit module: PDFium and pdf.js, LibreOfficeKit and ZetaOffice.
  'tom_forge_pdf_pdfium': 3,
  'tom_forge_pdf_pdfjs': 3,
  'tom_forge_office_lok': 3,
  'tom_forge_office_zetaoffice': 3,
  // The views as kit components, one package each (see _views): usable in
  // any layout, contributed through the module registry and placed by their
  // hints; the shell takes none of them (PL-11).
  'tom_forge_file_explorer': 3,
  'tom_forge_search_view': 3,
  'tom_forge_problems_view': 3,
  'tom_forge_outline_view': 3,
  'tom_forge_output_view': 3,
  'tom_forge_revision_view': 3,
  // Quick open and the command palette: the overlay a module contributes
  // (ForgeQuickOpenExtra), which the shell asks the registry for.
  'tom_forge_quick_open': 3,
  'tom_forge_command_palette': 3,
  // 4 Shell core.
  'tom_forge_shell': 4,
  // 5 Shell parts: what plugs into the core (ForgeShellComponents). The
  // terminal is the adapter of tom_terminal_view against the kit.
  'tom_forge_terminal': 5,
  // The three editor adapters re-exported, with the shell-typed helpers,
  // for one release.
  'tom_forge_code_editors': 5,
  'tom_forge_platform_secrets': 5,
  'tom_forge_desktop_host': 5,
  // 5 Test support (see _testSupport).
  'tom_forge_ui_testing': 5,
  // 6 The shell with its parts (the umbrella).
  'tom_forge_ui': 6,
  // 7 Shell services.
  'tom_forge_agentic': 7,
  // 8 Modules.
  'tom_forge_file_editors': 8,
  'tom_forge_quests': 8,
  'tom_website_editor': 8,
  'tom_specs_editor': 8,
  // 9 Module and adapter test support (see _testSupport): above the harness
  // they build on (tom_forge_ui_testing, layer 5).
  'tom_forge_file_editors_testing': 9,
  'tom_forge_md_editor_testing': 9,
  'tom_forge_yaml_editor_testing': 9,
  'tom_forge_office_lok_testing': 9,
  'tom_forge_office_zetaoffice_testing': 9,
  'tom_forge_pdf_pdfium_testing': 9,
  'tom_forge_pdf_pdfjs_testing': 9,
  // 10 Apps: Tom Forge, and the two examples of a lighter build — a
  // single-window YAML tool on the kit and the shared look, without the
  // panel shell, and the light panel shell with the file explorer and the
  // YAML editor.
  'tom_forge_app': 10,
  'tom_forge_single_window_example': 10,
  'tom_forge_lite_example': 10,
};

/// The layer of the applications: a harness package may depend on anything
/// below it.
const int _appsLayer = 10;

/// Test support: packages built on `flutter_test` for other packages'
/// suites. Any package may take one as a dev_dependency, also a lower one
/// (`tom_forge_ui`'s suites run the harness built on `tom_forge_ui`); as a
/// dependency they follow the layers like every other package.
const Set<String> _testSupport = <String>{
  'tom_forge_ui_testing',
  'tom_forge_file_editors_testing',
  'tom_forge_md_editor_testing',
  'tom_forge_yaml_editor_testing',
  'tom_forge_office_lok_testing',
  'tom_forge_office_zetaoffice_testing',
  'tom_forge_pdf_pdfium_testing',
  'tom_forge_pdf_pdfjs_testing',
};

/// The plugin packages of a layer-2 component, each with its component: a
/// plugin sits in the component's layer and is the one package of that layer
/// that may depend on it (PL-2), never the other way. An adapter may take its
/// editor's plugins (PL-8).
const Map<String, String> _componentPlugins = <String, String>{
  'tom_md_mermaid': 'tom_md_editor',
  'tom_md_math': 'tom_md_editor',
  'tom_md_docspecs': 'tom_md_editor',
  'tom_md_review': 'tom_md_editor',
  'tom_md_http': 'tom_md_editor',
  'tom_dart_analysis': 'tom_dart_editor',
};

/// The editor adapters (layer 3), each with the one editor it makes a Forge
/// editor (PL-8). Within layer 3 an adapter may take the shared look
/// (PL-2). The plain-text, PDF and office adapters' editors are tom_modules
/// packages, one engine or route each (R6).
const Map<String, String> _editorAdapters = <String, String>{
  'tom_forge_md_editor': 'tom_md_editor',
  'tom_forge_dart_editor': 'tom_dart_editor',
  'tom_forge_yaml_editor': 'tom_yaml_editor',
  'tom_forge_plain_text_editor': 'tom_file_editors',
  'tom_forge_pdf_pdfium': 'tom_pdf_editor',
  'tom_forge_pdf_pdfjs': 'tom_pdf_pdfjs',
  'tom_forge_office_lok': 'tom_office_editor',
  'tom_forge_office_zetaoffice': 'tom_office_zetaoffice',
};

/// The views (layer 3): kit components in a package each (CMP-2, R5), each
/// contributing its view through the module registry with a layout-free
/// placement hint. Within layer 3 a view may take the shared look (PL-2);
/// a view takes the kit and the light shared packages only, and the panel
/// shell takes no view (PL-11).
const Set<String> _views = <String>{
  'tom_forge_file_explorer',
  'tom_forge_search_view',
  'tom_forge_problems_view',
  'tom_forge_outline_view',
  'tom_forge_output_view',
  'tom_forge_revision_view',
  'tom_forge_quick_open',
  'tom_forge_command_palette',
};

/// What one view takes beyond the kit and the light shared packages
/// (PL-11), each with why.
const Map<String, Map<String, String>> _viewExtras =
    <String, Map<String, String>>{
      'tom_forge_file_explorer': {
        'tom_file_system':
            'the file tree it lists and changes (TomFileSystem, '
            'TomFileEntry), which the kit does not re-export',
      },
      'tom_forge_quick_open': {
        'tom_file_system':
            'the workspace files it searches (TomFileEntry), which the kit '
            'does not re-export',
      },
    };

/// What one adapter takes beyond its editor, the kit and the light shared
/// packages (PL-8), each with why.
const Map<String, Map<String, String>> _adapterExtras =
    <String, Map<String, String>>{
      'tom_forge_plain_text_editor': {
        'tom_file_system':
            'the file system its forFile and fromContent factories open the '
            'session in (an in-memory one for text without a file)',
      },
      'tom_forge_pdf_pdfium': {
        'tom_pdf_pdfium':
            'the PDFium engine the editor runs on (its one engine: no pdf.js, '
            'no webview)',
        'tom_file_session':
            'the binary save rules (TomBinaryFileAccess, '
            'TomFileSystemBinaryFiles)',
        'tom_file_system':
            'the application\'s file system, for files without a local path',
      },
      'tom_forge_pdf_pdfjs': {
        'tom_pdf_editor':
            'the view host every PDF view shares (TomPdfViewHost), never '
            'the PDFium engine',
        'tom_file_session':
            'the binary save rules and the content server '
            '(TomBinaryFileAccess, TomLocalContentServer)',
        'tom_file_system':
            'the application\'s file system, for files without a local path',
      },
      'tom_forge_office_lok': {
        'tom_file_session':
            'the binary save rules the host hands the editor (TomBinaryFiles)',
        'crypto':
            'the install runner\'s SHA-256 check of a managed LibreOffice '
            'download against its published hash',
      },
      'tom_forge_office_zetaoffice': {
        'tom_office_editor':
            'the host interface the ZetaOffice route runs on '
            '(TomOfficeEditorHost), shared with the native route',
        'tom_file_session':
            'the binary save rules the host hands the editor (TomBinaryFiles, '
            'TomBinaryFileAccess)',
      },
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

/// The two repositories of the platform, found from the working directory:
/// the libraries (`tom_forge_modules`, cloned at `tom_ai/forge_modules`) and
/// the application (`tom_forge`); null when either is not reachable.
List<Directory>? _repoRoots() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 4; i++) {
    if (File('${dir.path}/tom_repository.yaml').existsSync() &&
        Directory('${dir.path}/tom_forge_app').existsSync()) {
      final modules = Directory('${dir.parent.path}/tom_ai/forge_modules');
      if (!File('${modules.path}/tom_repository.yaml').existsSync() ||
          !Directory('${modules.path}/tom_forge_ui').existsSync()) {
        return null;
      }
      return [modules, dir];
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

/// Every top-level package of the two repositories, by name.
Map<String, _Package> _packages(List<Directory> roots) {
  final out = <String, _Package>{};
  for (final dir in [
    for (final root in roots) ...root.listSync().whereType<Directory>(),
  ]) {
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
  final roots = _repoRoots();
  final packages = roots == null ? <String, _Package>{} : _packages(roots);

  bool reachable() {
    if (roots != null) return true;
    markTestSkipped(
      'tom_forge / tom_forge_modules roots not reachable — nothing to check',
    );
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
          // Layer 3 holds the shared look and the editor adapters; an
          // adapter may take the shared look (PL-8), never the other way.
          if ((_editorAdapters.containsKey(from) || _views.contains(from)) &&
              to == 'tom_forge_shared_ui') {
            continue;
          }
          // Within its component's layer a plugin package takes its
          // component, never the other way.
          if (_componentPlugins[from] == to) continue;
          if (_harness.contains(to)) {
            offenders.add('$from has a $kind on the harness package $to');
          } else if (_harness.contains(from)) {
            if (_layers[to] == _appsLayer) {
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

    test('PL-6: the shared look takes Flutter, tom_ui_support, tom_forge_core, '
        'tom_forge_kit and tom_file_session_ui only', () {
      if (!reachable()) return;
      final shared = packages['tom_forge_shared_ui'];
      expect(shared, isNotNull);
      const allowed = {
        'flutter',
        'tom_ui_support',
        'tom_forge_core',
        'tom_forge_kit',
        // The session file's frame (one implementation with
        // tom_file_editors): Flutter and tom_file_session only.
        'tom_file_session_ui',
      };
      // Its tests run on a bare kit: an in-memory file system and an editor
      // of the editor kit's contract.
      const allowedDev = {
        'flutter_test',
        'flutter_lints',
        'tom_file_system',
        'tom_editors_shared',
      };
      expect(
        {
          for (final d in shared!.dependencies)
            if (!(d.dev ? allowedDev : allowed).contains(d.name))
              '${d.name}${d.dev ? ' (dev)' : ''}',
        },
        isEmpty,
        reason:
            'tom_forge_shared_ui is one rendering of the Forge kit\'s models '
            'that Webwork and any application take for Forge\'s look: the '
            'kit and its tokens, no shell, no terminal, no editors, no '
            'webview.',
      );
    });

    test('PL-8: an editor adapter takes its editor, its editor\'s plugins, '
        'the kit and light shared packages only, never the shell', () {
      if (!reachable()) return;
      // R9: a component or adapter depends on tom_forge_kit (and
      // tom_forge_shared_ui when it shows kit UI), never on tom_forge_shell.
      const adapters = _editorAdapters;
      const shared = {
        'flutter',
        'tom_forge_kit',
        'tom_forge_shared_ui',
        'tom_forge_core',
        'tom_editors_shared',
      };
      // Its suites may take test support (the undo harness, its file kind's
      // undo subject); that never reaches the adapter itself.
      const allowedDev = {'flutter_test', 'flutter_lints'};
      final offenders = <String>[];
      for (final MapEntry(key: name, value: editor) in adapters.entries) {
        final package = packages[name];
        if (package == null) {
          offenders.add('$name is missing');
          continue;
        }
        for (final d in package.dependencies) {
          final ok = d.dev
              ? allowedDev.contains(d.name) || _testSupport.contains(d.name)
              : d.name == editor ||
                    _componentPlugins[d.name] == editor ||
                    shared.contains(d.name) ||
                    (_adapterExtras[name]?.containsKey(d.name) ?? false);
          if (!ok) offenders.add('$name: ${d.name}${d.dev ? ' (dev)' : ''}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'An editor adapter is its editor made a Forge editor over the '
            'kit: one editor with its plugin packages, the kit and light '
            'shared packages, so an '
            'application takes one adapter without the others\' editors '
            '(platform_architecture.md §1).\n${offenders.join('\n')}',
      );
    });

    test('PL-9: the file editors take neither the Markdown nor the YAML '
        'editor; they learn those kinds from the registry', () {
      if (!reachable()) return;
      final fileEditors = packages['tom_forge_file_editors'];
      expect(fileEditors, isNotNull);
      const heavy = {
        'tom_md_editor',
        'tom_md_mermaid',
        'tom_md_math',
        'tom_md_docspecs',
        'tom_md_review',
        'tom_md_http',
        'tom_yaml_editor',
        'tom_forge_md_editor',
        'tom_forge_yaml_editor',
      };
      expect(
        {
          for (final d in fileEditors!.dependencies)
            if (!d.dev && heavy.contains(d.name)) d.name,
        },
        isEmpty,
        reason:
            'tom_forge_file_editors keeps .env, plain text and todo files; '
            'the Markdown and YAML file kinds are their adapters\' and reach '
            'the module through the ForgeFileKindRegistry the application '
            'fills, so an application that only wants .env files takes no '
            'webview and no math library (platform_architecture.md §1).',
      );
    });

    test('PL-10: the terminal view takes no Forge package', () {
      if (!reachable()) return;
      final view = packages['tom_terminal_view'];
      expect(view, isNotNull);
      expect(
        {
          for (final d in view!.dependencies)
            if (packages.containsKey(d.name))
              '${d.name}${d.dev ? ' (dev)' : ''}',
        },
        isEmpty,
        reason:
            'tom_terminal_view is a terminal for any Flutter UI (the shell in '
            'a pseudo-terminal and the xterm widget); Forge\'s Terminal view, '
            'the terminal managers and their registration are its adapter\'s, '
            'tom_forge_terminal (platform_architecture.md §1).',
      );
    });

    test('PL-11: a view takes the kit and light shared packages only, and '
        'the panel shell takes no view', () {
      if (!reachable()) return;
      // R5 and R9: a view is a kit component its package contributes through
      // the module registry; neither the kit nor the shell names it.
      const shared = {
        'flutter',
        'tom_forge_kit',
        'tom_forge_shared_ui',
        'tom_forge_core',
        'tom_editors_shared',
      };
      const allowedDev = {
        'flutter_test',
        'flutter_lints',
        // The bare kit's tests run over an in-memory file system.
        'tom_file_system',
        'tom_forge_core',
      };
      final offenders = <String>[];
      for (final name in _views) {
        final package = packages[name];
        if (package == null) {
          offenders.add('$name is missing');
          continue;
        }
        for (final d in package.dependencies) {
          final ok = d.dev
              ? allowedDev.contains(d.name) || _testSupport.contains(d.name)
              : shared.contains(d.name) ||
                    (_viewExtras[name]?.containsKey(d.name) ?? false);
          if (!ok) offenders.add('$name: ${d.name}${d.dev ? ' (dev)' : ''}');
        }
      }
      for (final d in packages['tom_forge_shell']?.dependencies ?? const []) {
        if (_views.contains(d.name)) {
          offenders.add(
            'tom_forge_shell has a ${d.dev ? 'dev_dependency' : 'dependency'} '
            'on the view ${d.name}',
          );
        }
      }
      // Nor does its library name one: no import, export or mention of a
      // view package anywhere under lib/.
      final shell = packages['tom_forge_shell'];
      final shellLib = shell == null
          ? null
          : Directory('${shell.dir.path}/lib');
      if (shellLib != null && shellLib.existsSync()) {
        for (final file
            in shellLib.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final text = file.readAsStringSync();
          for (final view in _views) {
            if (text.contains(view)) {
              final relative = file.path.substring(shell!.dir.path.length + 1);
              offenders.add('tom_forge_shell/$relative names the view $view');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A view is a kit component usable in any layout: it takes the '
            'kit (and the shared look when it shows kit UI), never the shell, '
            'and the shell builds without it; an application registers the '
            'view\'s module (platform_architecture.md §1).\n'
            '${offenders.join('\n')}',
      );
    });

    test('PL-7: no Forge package takes the umbrella tom_forge_ui', () {
      if (!reachable()) return;
      final offenders = <String>[
        for (final package in packages.values)
          if (package.name != 'tom_forge_ui')
            for (final dep in package.dependencies)
              if (dep.name == 'tom_forge_ui')
                '${package.name} has a ${dep.dev ? 'dev_dependency' : 'dependency'} '
                    'on tom_forge_ui',
      ];
      // An import compiles through a dependency of a dependency as well: no
      // Dart file of another package imports or exports the umbrella.
      // (`[/]`, so the repository-wide grep for the umbrella's package URI
      // does not find this guard itself.)
      final directive = RegExp(
        r'''^\s*(import|export)\s+['"]package:tom_forge_ui[/]''',
        multiLine: true,
      );
      for (final package in packages.values) {
        if (package.name == 'tom_forge_ui') continue;
        for (final folder in const [
          'lib',
          'test',
          'integration_test',
          'tool',
          'example',
        ]) {
          final dir = Directory('${package.dir.path}/$folder');
          if (!dir.existsSync()) continue;
          for (final file in dir.listSync(recursive: true).whereType<File>()) {
            final path = file.path.replaceAll(r'\', '/');
            if (!path.endsWith('.dart') ||
                path.contains('/.dart_tool/') ||
                path.contains('/build/')) {
              continue;
            }
            if (directive.hasMatch(file.readAsStringSync())) {
              offenders.add(
                '${package.name}: '
                '${file.path.substring(package.dir.parent.path.length + 1)} '
                'imports tom_forge_ui',
              );
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'tom_forge_ui is the full-desktop umbrella for consumers outside '
            'tom_forge (platform_architecture.md §3): a Forge package takes '
            'the kit and the parts it uses, and the shell only for the panel '
            'shell\'s extras.\n${offenders.join('\n')}',
      );
    });
  });
}
