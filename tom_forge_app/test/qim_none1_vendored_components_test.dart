/// qim_none-1, DPFI-1: the native and web components that reach a user
/// without being a Dart package — the `third_party/` folders of the Tom
/// packages this app links, and the licence files of their assets — are each
/// listed in `THIRD_PARTY.md` and licensed within the admitted families.
///
/// The Dart audit (`qim_none1_licence_audit_test.dart`) reads one `LICENSE`
/// per package, so a vendored copy of PDFium's headers or of pdf.js inside a
/// BSD-3 package passes it whatever that copy's terms are. This test reads
/// every licence file inside each component instead.
///
/// Admitted: the permissive families of the Dart audit, and for fonts and
/// data the SIL Open Font License 1.1 and CC0-1.0. A component is a direct
/// child of a package's `third_party/` folder, or the folder of a licence file
/// under its `assets/` or `fonts/`. Run `flutter pub get` first.
///
/// **The binaries layer** (QIMN1-7, QIMN1-8). A program the app starts as a
/// process (`tom_office_host`, the LibreOfficeKit helper) is no Dart package
/// the app links, so the walk above never reaches it, and Webwork's lock test
/// reads only `pubspec.lock`. The second group reads `tom_binaries/LICENSE`:
/// every binary row names its package, the package is in the workspace, and
/// every vendored component of it has a row in that package's
/// `THIRD_PARTY.md` and an admitted licence. For these the admitted families
/// include MPL-2.0 (file-level copyleft, which a BSD-3 binary may carry as a
/// Larger Work) when the component says where its Source Code Form is, a
/// `SOURCE.md` beside it or a URL in its row (MPL-2.0 §3.2(a)). It lives here
/// rather than in tom_binaries, which has no test runner: Forge's suite runs
/// it on every `testkit :test`, with the component logic of the first group.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_test_support/licence_audit.dart';
import 'package:tom_test_support/roots.dart';

/// One vendored component: the package, its folder relative to the package
/// root, and the licence files in it.
typedef _Component = ({
  String package,
  String root,
  String folder,
  List<File> licences,
});

/// Whether [name] is the name of a licence file.
bool _isLicenceFile(String name) {
  final upper = name.toUpperCase();
  return upper.startsWith('LICENSE') ||
      upper.startsWith('LICENCE') ||
      upper.startsWith('COPYING') ||
      upper.startsWith('OFL');
}

/// The licence families a vendored component may carry, by [text]: a
/// [TomLicence] of the permissive families, `OFL-1.1` or `CC0-1.0`; null for
/// any other text (a GPL family among them).
String? _admittedFamily(String text) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ');
  if (tomIsGplFamily(t)) return null;
  final licence = tomClassifyLicence(t);
  if (licence != null) {
    return TomLicence.permissive.contains(licence) ? licence.name : null;
  }
  if (t.toUpperCase().contains('SIL OPEN FONT LICENSE VERSION 1.1')) {
    return 'OFL-1.1';
  }
  if (t.contains('CC0 1.0 Universal')) return 'CC0-1.0';
  return null;
}

/// The licence files under [dir], recursively.
List<File> _licencesUnder(Directory dir) => [
  for (final entity in dir.listSync(recursive: true, followLinks: false))
    if (entity is File && _isLicenceFile(p.basename(entity.path))) entity,
]..sort((a, b) => a.path.compareTo(b.path));

/// The vendored components of the package [name] at [root].
List<_Component> _componentsOf(String name, Directory root) {
  final components = <_Component>[];
  final thirdParty = Directory(p.join(root.path, 'third_party'));
  if (thirdParty.existsSync()) {
    for (final child
        in thirdParty.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
      if (child is! Directory) continue;
      components.add((
        package: name,
        root: root.path,
        folder: p.posix.join('third_party', p.basename(child.path)),
        licences: _licencesUnder(child),
      ));
    }
  }
  for (final assets in ['assets', 'fonts']) {
    final dir = Directory(p.join(root.path, assets));
    if (!dir.existsSync()) continue;
    final byFolder = <String, List<File>>{};
    for (final file in _licencesUnder(dir)) {
      final folder = p.relative(file.parent.path, from: root.path);
      (byFolder[p.split(folder).join('/')] ??= []).add(file);
    }
    for (final e in byFolder.entries) {
      components.add((
        package: name,
        root: root.path,
        folder: e.key,
        licences: e.value,
      ));
    }
  }
  return components;
}

/// The folders the *Vendored and shipped components* table of [notice]
/// names: each `<package>/<folder>` in backticks in a row's *Where* column.
Set<String> _noticedComponents(File notice) {
  final lines = notice.readAsLinesSync();
  final start = lines.indexWhere(
    (l) => l.startsWith('## Vendored and shipped components'),
  );
  if (start < 0) return {};
  final names = <String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('## ')) break;
    final cells = line.split('|');
    if (cells.length < 4 || !line.startsWith('| ')) continue;
    for (final m in RegExp(r'`(tom_[a-z0-9_]+/[^`]+)`').allMatches(cells[2])) {
      names.add(m.group(1)!);
    }
  }
  return names;
}

/// What is wrong with [components] against the [noticed] rows: a component
/// without a row, without a licence file, or with a licence file outside the
/// admitted families; MPL-2.0 without its source location (a `SOURCE.md`
/// beside it or a URL in its row, [rowOf]); a row naming no component.
List<String> _problems(
  List<_Component> components,
  Set<String> noticed, {
  String? Function(String id)? rowOf,
}) {
  final problems = <String>[];
  final found = <String>{};
  for (final c in components) {
    final id = '${c.package}/${c.folder}';
    found.add(id);
    if (!noticed.contains(id)) {
      problems.add('$id is vendored but THIRD_PARTY.md has no row for it.');
    }
    if (c.licences.isEmpty) {
      problems.add('$id carries no licence file.');
    }
    for (final file in c.licences) {
      final text = file.readAsStringSync();
      if (_admittedFamily(text) != null) continue;
      // MPL-2.0 is file-level copyleft a BSD-3 app may carry, when the
      // component says where its source is (MPL-2.0 §3.2(a)), as QIMN1-7
      // admits it for the binaries layer.
      if (tomClassifyLicence(text) == TomLicence.mpl2) {
        final sourced =
            File(p.join(c.root, c.folder, 'SOURCE.md')).existsSync() ||
            (rowOf?.call(id)?.contains(RegExp(r'https?://')) ?? false);
        if (!sourced) {
          problems.add(
            '$id is MPL-2.0 but names no source location (a SOURCE.md '
            'beside it or a URL in its THIRD_PARTY row; MPL-2.0 §3.2(a)).',
          );
        }
        continue;
      }
      problems.add(
        '$id: ${p.basename(file.path)} is not a licence of the admitted '
        'families (permissive, OFL-1.1, CC0-1.0, MPL-2.0 with its source).',
      );
    }
  }
  for (final id in noticed.difference(found)) {
    problems.add('THIRD_PARTY.md lists $id, but no linked package vendors it.');
  }
  return problems;
}

// ------------------------------------------------------- binaries layer

/// One binary row of `tom_binaries/LICENSE`: the binaries, the package and
/// the source repository column.
typedef _BinaryRow = ({String binaries, String package, String source});

/// The rows of the binaries table (the first table, `| Binary ... |`) of
/// [licence].
List<_BinaryRow> _binaryRows(File licence) {
  final rows = <_BinaryRow>[];
  var inTable = false;
  for (final line in licence.readAsLinesSync()) {
    if (line.startsWith('| Binary')) {
      inTable = true;
      continue;
    }
    if (!inTable) continue;
    if (!line.startsWith('|')) break;
    if (line.startsWith('| ---') || line.startsWith('|---')) continue;
    final cells = line.split('|').map((c) => c.trim()).toList();
    if (cells.length < 5) continue;
    rows.add((binaries: cells[1], package: cells[2], source: cells[3]));
  }
  return rows;
}

/// Folders [packageIndex] does not descend into.
const _skipped = {
  'build',
  '.dart_tool',
  '.git',
  'ztmp',
  'node_modules',
  'testlog',
  '_ai',
  'release',
};

/// Every Dart package of [workspace] by its pubspec `name:`, down to six
/// levels (a package's folder need not be its name: `tsm` is
/// `tom_secrets_tsm`).
Map<String, Directory> _packageIndex(Directory workspace) {
  final index = <String, Directory>{};
  void visit(Directory dir, int depth) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final m = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync());
      if (m != null) index.putIfAbsent(m.group(1)!, () => dir);
    }
    if (depth == 6) return;
    final List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final child in children) {
      final name = p.basename(child.path);
      if (child is! Directory ||
          _skipped.contains(name) ||
          name.startsWith('zom_') ||
          (name.startsWith('.') && name != '.')) {
        continue;
      }
      visit(child, depth + 1);
    }
  }

  visit(workspace, 0);
  return index;
}

/// The row of [notice] (a package's `THIRD_PARTY.md`) that names [folder],
/// or null.
String? _rowNaming(File notice, String folder) {
  if (!notice.existsSync()) return null;
  for (final line in notice.readAsLinesSync()) {
    if (line.startsWith('|') && line.contains(folder)) return line;
  }
  return null;
}

/// What is wrong with the binaries layer's [rows] against the packages of
/// [index]: a row without a package, a package not in the workspace, a
/// vendored component without a row in its package's `THIRD_PARTY.md`,
/// without a licence file, with a licence outside the admitted families, or
/// MPL-2.0 without its source location.
List<String> _binaryProblems(
  List<_BinaryRow> rows,
  Map<String, Directory> index,
) {
  final problems = <String>[];
  for (final row in rows) {
    final package = row.package;
    if (package.isEmpty ||
        (package == '-' && !row.source.contains('this repository'))) {
      problems.add('tom_binaries/LICENSE: "${row.binaries}" names no package.');
      continue;
    }
    if (package == '-') continue; // a script of the binaries repository
    final root = index[package];
    if (root == null) {
      problems.add(
        'tom_binaries/LICENSE: $package (${row.binaries}) is not a package '
        'of this workspace, so what it vendors cannot be checked.',
      );
      continue;
    }
    final notice = File(p.join(root.path, 'THIRD_PARTY.md'));
    for (final c in _componentsOf(package, root)) {
      final id = '$package/${c.folder}';
      final line = _rowNaming(notice, c.folder);
      if (line == null) {
        problems.add(
          '$id ships in ${row.binaries} but $package/THIRD_PARTY.md has no '
          'row for it.',
        );
      }
      if (c.licences.isEmpty) problems.add('$id carries no licence file.');
      for (final file in c.licences) {
        final text = file.readAsStringSync();
        if (_admittedFamily(text) != null) continue;
        if (tomClassifyLicence(text) == TomLicence.mpl2) {
          final sourced =
              File(p.join(root.path, c.folder, 'SOURCE.md')).existsSync() ||
              (line?.contains(RegExp(r'https?://')) ?? false);
          if (!sourced) {
            problems.add(
              '$id is MPL-2.0 but names no source location (a SOURCE.md '
              'beside it or a URL in its THIRD_PARTY row; MPL-2.0 §3.2(a)).',
            );
          }
          continue;
        }
        problems.add(
          '$id: ${p.basename(file.path)} is not a licence of the admitted '
          'families (permissive, OFL-1.1, CC0-1.0, MPL-2.0 with its source).',
        );
      }
    }
  }
  return problems;
}

void main() {
  final appRoot = p.join(tomFindRepositoryRoot().path, 'tom_forge_app');

  test('QIMN1-5: every vendored component of the linked Tom packages has a '
      'THIRD_PARTY row and an admitted licence', () {
    final packages = tomResolvedPackages('tom_forge_app');
    final linked = tomLinkedPackages('tom_forge_app', packages);
    final components = [
      for (final package in linked)
        if (!package.sdk && package.name.startsWith('tom_'))
          ..._componentsOf(package.name, package.root),
    ];
    final ids = components.map((c) => '${c.package}/${c.folder}').toSet();
    // Anti-vacuity: the PDF editors' PDFium headers and pdf.js are reached,
    // with the licence files of pdf.js's data, and the office editors'
    // zetajs.
    expect(
      ids,
      containsAll([
        'tom_pdf_pdfium/third_party/pdfium',
        'tom_pdf_pdfjs/third_party/pdfjs',
        'tom_office_zetaoffice/assets/zetaoffice',
      ]),
    );
    final pdfjs = components.firstWhere((c) => c.folder == 'third_party/pdfjs');
    expect(pdfjs.licences.length, greaterThan(5));
    final notice = File(p.join(appRoot, 'THIRD_PARTY.md'));
    final problems = _problems(
      components,
      _noticedComponents(notice),
      rowOf: (id) => _rowNaming(notice, '`$id`'),
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('QIMN1-6: a component without a row, one under the GPL, one without '
      'a licence, an MPL-2.0 one without its source and a row for nothing '
      'each fail by name', () {
    final scratch = tomWorkspaceZtmp().createTempSync('qim_none1_vendored_');
    addTearDown(() => scratch.deleteSync(recursive: true));
    void file(String path, String text) => (File(
      p.join(scratch.path, path),
    )..createSync(recursive: true)).writeAsStringSync(text);
    file('third_party/fine/LICENSE', 'Apache License\nVersion 2.0');
    file(
      'third_party/fine/data/LICENSE_FONT',
      'SIL OPEN FONT LICENSE Version 1.1',
    );
    file('third_party/gpl/LICENSE', 'Apache License Version 2.0');
    file('third_party/gpl/fonts/LICENSE', 'GNU General Public License');
    file('third_party/bare/README', 'no licence');
    const mpl = 'Mozilla Public License Version 2.0';
    file('third_party/mpl/LICENSE', mpl);
    file('third_party/mplsourced/LICENSE', mpl);
    file('third_party/mplsourced/SOURCE.md', 'from upstream');
    file('third_party/mplrow/LICENSE', mpl);
    file('assets/icons/LICENSE', 'CC0 1.0 Universal');
    file(
      'assets/unlisted/LICENSE',
      'Permission is hereby granted, free of charge',
    );
    final components = _componentsOf('tom_x', scratch);
    expect(components.map((c) => c.folder), [
      'third_party/bare',
      'third_party/fine',
      'third_party/gpl',
      'third_party/mpl',
      'third_party/mplrow',
      'third_party/mplsourced',
      'assets/icons',
      'assets/unlisted',
    ]);
    final problems = _problems(
      components,
      {
        'tom_x/third_party/fine',
        'tom_x/third_party/gpl',
        'tom_x/third_party/bare',
        'tom_x/third_party/mpl',
        'tom_x/third_party/mplrow',
        'tom_x/third_party/mplsourced',
        'tom_x/assets/icons',
        'tom_x/third_party/gone',
      },
      rowOf: (id) => id == 'tom_x/third_party/mplrow'
          ? '| headers | `$id` | MPL-2.0, source https://example.org/x |'
          : null,
    );
    expect(problems, hasLength(5), reason: problems.join('\n'));
    expect(problems[0], contains('third_party/bare carries no licence'));
    expect(
      problems[1],
      allOf(contains('third_party/gpl'), contains('not a licence')),
    );
    expect(
      problems[2],
      allOf(contains('third_party/mpl '), contains('names no source')),
    );
    expect(problems[3], contains('assets/unlisted is vendored but'));
    expect(problems[4], contains('third_party/gone, but no linked package'));
  });

  test('QIMN1-7: every binary of the binaries layer names its package, and '
      'every component that package vendors has a THIRD_PARTY row and an '
      'admitted licence (MPL-2.0 with its source)', () {
    final workspace = tomWorkspaceZtmp().parent;
    final licence = File(p.join(workspace.path, 'tom_binaries', 'LICENSE'));
    expect(
      licence.existsSync(),
      isTrue,
      reason: 'the binaries layer (tom_binaries) is cloned beside the code',
    );
    final rows = _binaryRows(licence);
    final index = _packageIndex(workspace);
    // Anti-vacuity: the office helper is a row, its package is found, and
    // its vendored MPL headers are among the components checked.
    expect(rows.map((r) => r.package), contains('tom_office_host'));
    final host = index['tom_office_host'];
    expect(host, isNotNull);
    expect(
      _componentsOf('tom_office_host', host!).map((c) => c.folder),
      contains('third_party/libreofficekit'),
    );
    final problems = _binaryProblems(rows, index);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('QIMN1-8: a binary row without a package, a package not in the '
      'workspace, an unlisted component, a GPL one and an MPL-2.0 one without '
      'its source each fail by name', () {
    final scratch = tomWorkspaceZtmp().createTempSync('qim_none1_binaries_');
    addTearDown(() => scratch.deleteSync(recursive: true));
    void file(String path, String text) => (File(
      p.join(scratch.path, path),
    )..createSync(recursive: true)).writeAsStringSync(text);
    const mpl = 'Mozilla Public License Version 2.0';
    file('tom_ok/pubspec.yaml', 'name: tom_ok\n');
    file('tom_ok/third_party/headers/LICENSE', mpl);
    file('tom_ok/third_party/headers/SOURCE.md', 'from upstream');
    file('tom_ok/third_party/lib/LICENSE', 'Apache License Version 2.0');
    file(
      'tom_ok/THIRD_PARTY.md',
      '| x | third_party/headers | MPL-2.0 |\n'
          '| y | third_party/lib | Apache-2.0 |\n',
    );
    file('folder/tom_bad/pubspec.yaml', 'name: tom_bad\n');
    file(
      'folder/tom_bad/third_party/unlisted/LICENSE',
      'Apache License Version 2.0',
    );
    file(
      'folder/tom_bad/third_party/gpl/LICENSE',
      'GNU General Public License',
    );
    file('folder/tom_bad/third_party/mpl/LICENSE', mpl);
    file(
      'folder/tom_bad/THIRD_PARTY.md',
      '| a | third_party/gpl | GPL |\n| b | third_party/mpl | MPL-2.0 |\n',
    );
    final rows = <_BinaryRow>[
      (binaries: 'ok', package: 'tom_ok', source: 'x'),
      (binaries: 'bad', package: 'tom_bad', source: 'x'),
      (binaries: 'gone', package: 'tom_gone', source: 'x'),
      (binaries: 'nameless', package: '', source: 'x'),
      (binaries: 'script', package: '-', source: 'this repository'),
    ];
    final index = _packageIndex(scratch);
    expect(index.keys, unorderedEquals(['tom_ok', 'tom_bad']));
    final problems = _binaryProblems(rows, index);
    expect(problems, hasLength(5), reason: problems.join('\n'));
    expect(problems, [
      contains('tom_bad/third_party/gpl: LICENSE is not a licence'),
      contains('tom_bad/third_party/mpl is MPL-2.0 but names no source'),
      contains('tom_bad/third_party/unlisted ships in bad but'),
      contains('tom_gone (gone) is not a package of this workspace'),
      contains('"nameless" names no package'),
    ]);
  });
}
