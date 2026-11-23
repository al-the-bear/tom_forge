/// qim_none-1: Tom Forge is distributable as BSD-3 on its own, so every
/// package this app links grants permissive terms, or MPL-2.0 with the
/// notice `THIRD_PARTY.md` carries — and nothing under a GPL family.
///
/// The LGPL is not admitted either: an ahead-of-time Flutter build links
/// statically and cannot honour its relinking requirement. MPL-2.0 is copyleft
/// per file only; it is admitted for the packages `THIRD_PARTY.md` lists under
/// it, and the notice names exactly the MPL-2.0 packages the app links.
///
/// The audit is `tom_test_support`'s (`licence_audit.dart`), run over the
/// packages this app resolves (`dependencies:` walked from `tom_forge_app`,
/// dev dependencies left out). Run `flutter pub get` first: the package
/// configuration is what it reads.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_test_support/licence_audit.dart';
import 'package:tom_test_support/roots.dart';

/// What Tom Forge admits: the permissive families, and MPL-2.0 with notice.
const _forgeAdmits = {...TomLicence.permissive, TomLicence.mpl2};

/// The audit under Forge's terms: [tomAuditLicences], then every MPL-2.0
/// package held against the packages the notice lists under it, both ways.
({Map<String, TomLicence> granted, List<String> problems}) _forgeAudit(
  List<TomLinkedPackage> linked,
  Set<String> noticedMpl,
) {
  final audit = tomAuditLicences(linked, admitted: _forgeAdmits);
  final mpl = {
    for (final e in audit.granted.entries)
      if (e.value == TomLicence.mpl2) e.key,
  };
  return (
    granted: audit.granted,
    problems: [
      ...audit.problems,
      for (final name in mpl.difference(noticedMpl))
        '$name is MPL-2.0 and THIRD_PARTY.md does not list it: the notice '
            'is the condition MPL-2.0 is admitted on.',
      for (final name in noticedMpl.difference(mpl))
        'THIRD_PARTY.md lists $name under MPL-2.0, but the app links no '
            'MPL-2.0 package of that name.',
    ],
  );
}

/// The packages `THIRD_PARTY.md` lists in its MPL-2.0 table: the first
/// column of each row, a package name in backticks.
Set<String> _noticedMpl(File notice) {
  final lines = notice.readAsLinesSync();
  final start = lines.indexWhere((l) => l.startsWith('## MPL-2.0'));
  if (start < 0) return {};
  final names = <String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('## ')) break;
    final row = RegExp(r'^\| `([a-z0-9_]+)` \|').firstMatch(line);
    if (row != null) names.add(row.group(1)!);
  }
  return names;
}

void main() {
  final appRoot = p.join(tomFindRepositoryRoot().path, 'tom_forge_app');

  group('QIMN1 — Tom Forge links nothing a BSD-3 app cannot carry', () {
    late Map<String, Directory> packages;
    late List<TomLinkedPackage> linked;
    setUpAll(() {
      packages = tomResolvedPackages('tom_forge_app');
      linked = tomLinkedPackages('tom_forge_app', packages);
    });

    test('QIMN1-1: every linked package is permissive, or MPL-2.0 and in '
        'THIRD_PARTY.md', () {
      final names = linked.map((e) => e.name).toSet();
      // Anti-vacuity: the walk reaches Forge's modules and what pub.dev
      // supplies below them.
      expect(
        names,
        containsAll([
          'tom_forge_shell',
          'tom_website_editor',
          'tom_website_editor_core',
          'tom_dart_editor',
          'flutter_inappwebview',
          'file_picker',
          // The PDF editors and the FFI they reach PDFium through.
          'tom_forge_pdf_editors',
          'tom_pdf_editor',
          'ffi',
          // The office editors and the office editor they compose.
          'tom_forge_office_editors',
          'tom_office_editor',
        ]),
      );
      final audit = _forgeAudit(
        linked,
        _noticedMpl(File(p.join(appRoot, 'THIRD_PARTY.md'))),
      );
      expect(audit.problems, isEmpty, reason: audit.problems.join('\n'));
      expect(audit.granted.keys.toSet(), names);
    });

    test(
      'QIMN1-2: no build tooling, so no LGPL `ini`, in the resolved graph',
      () {
        // tom_build_base is CLI tooling; its dcli brought `ini` (LGPL-3.0).
        for (final tooling in ['tom_build_base', 'dcli', 'dcli_core', 'ini']) {
          expect(packages.keys, isNot(contains(tooling)), reason: tooling);
        }
      },
    );

    test('QIMN1-3: every Tom package the app links is BSD-3-Clause', () {
      final audit = tomAuditLicences(linked, admitted: _forgeAdmits);
      final tom = linked.where((e) => e.name.startsWith('tom_'));
      expect(tom, isNotEmpty);
      for (final package in tom) {
        expect(
          audit.granted[package.name],
          TomLicence.bsd3,
          reason: package.name,
        );
      }
    });
  });

  test('QIMN1-4: an LGPL package, and an MPL-2.0 package the notice does not '
      'list, each fail by name', () {
    final scratch = tomWorkspaceZtmp().createTempSync('qim_none1_licence_');
    addTearDown(() => scratch.deleteSync(recursive: true));
    Directory make(String name, String licence) {
      final dir = Directory(p.join(scratch.path, name))..createSync();
      File(p.join(dir.path, 'LICENSE')).writeAsStringSync(licence);
      return dir;
    }

    const mpl = 'Mozilla Public License Version 2.0';
    final linked = <TomLinkedPackage>[
      (
        name: 'granted',
        root: make(
          'granted',
          'Permission is hereby granted, free of charge, to any person',
        ),
        sdk: false,
      ),
      (
        name: 'lesser',
        root: make(
          'lesser',
          'GNU LESSER GENERAL PUBLIC LICENSE\nGNU Lesser General Public '
              'License',
        ),
        sdk: false,
      ),
      (name: 'noticed', root: make('noticed', mpl), sdk: false),
      (name: 'unnoticed', root: make('unnoticed', mpl), sdk: false),
    ];
    final audit = _forgeAudit(linked, {'noticed', 'gone'});
    expect(audit.problems, hasLength(3), reason: audit.problems.join('\n'));
    expect(audit.problems[0], contains('lesser'));
    expect(
      audit.problems[1],
      allOf(contains('unnoticed'), contains('does not list it')),
    );
    expect(
      audit.problems[2],
      allOf(contains('gone'), contains('links no MPL-2.0 package')),
    );
  });
}
