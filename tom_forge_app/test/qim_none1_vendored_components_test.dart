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
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_test_support/licence_audit.dart';
import 'package:tom_test_support/roots.dart';

/// One vendored component: the package, its folder relative to the package
/// root, and the licence files in it.
typedef _Component = ({String package, String folder, List<File> licences});

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
      components.add((package: name, folder: e.key, licences: e.value));
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
/// admitted families; a row naming no component.
List<String> _problems(List<_Component> components, Set<String> noticed) {
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
      if (_admittedFamily(file.readAsStringSync()) == null) {
        problems.add(
          '$id: ${p.basename(file.path)} is not a licence of the admitted '
          'families (permissive, OFL-1.1, CC0-1.0).',
        );
      }
    }
  }
  for (final id in noticed.difference(found)) {
    problems.add('THIRD_PARTY.md lists $id, but no linked package vendors it.');
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
    // with the licence files of pdf.js's data.
    expect(
      ids,
      containsAll([
        'tom_pdf_editor/third_party/pdfium',
        'tom_pdf_editor/third_party/pdfjs',
      ]),
    );
    final pdfjs = components.firstWhere((c) => c.folder == 'third_party/pdfjs');
    expect(pdfjs.licences.length, greaterThan(5));
    final problems = _problems(
      components,
      _noticedComponents(File(p.join(appRoot, 'THIRD_PARTY.md'))),
    );
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('QIMN1-6: a component without a row, one under the GPL, one without '
      'a licence and a row for nothing each fail by name', () {
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
      'assets/icons',
      'assets/unlisted',
    ]);
    final problems = _problems(components, {
      'tom_x/third_party/fine',
      'tom_x/third_party/gpl',
      'tom_x/third_party/bare',
      'tom_x/assets/icons',
      'tom_x/third_party/gone',
    });
    expect(problems, hasLength(4), reason: problems.join('\n'));
    expect(problems[0], contains('third_party/bare carries no licence'));
    expect(
      problems[1],
      allOf(contains('third_party/gpl'), contains('not a licence')),
    );
    expect(problems[2], contains('assets/unlisted is vendored but'));
    expect(problems[3], contains('third_party/gone, but no linked package'));
  });
}
