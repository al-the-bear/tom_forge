/// The command line of Tom Forge's own app ([ForgeLaunch]): the folder, the
/// files to open, the trails.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_app/forge_suite.dart';

void main() {
  test('FL-1: --workspace, files and --trail are read; without a folder the '
      'first file\'s is taken', () {
    final a = ForgeLaunch.parse([
      '--workspace=/ws',
      '/ws/docs/a.pdf',
      '--trail=pdf, other',
      '-v',
    ]);
    expect(a.workspace!.path, '/ws');
    expect(a.documents, ['/ws/docs/a.pdf']);
    expect(a.trails, {'pdf', 'other'});

    final b = ForgeLaunch.parse(['--workspace', '/w2']);
    expect(b.workspace!.path, '/w2');
    expect(b.documents, isEmpty);

    final c = ForgeLaunch.parse(['/x/y/report.docx', '/x/z.pdf']);
    expect(c.workspace!.path, '/x/y');
    expect(c.documents, ['/x/y/report.docx', '/x/z.pdf']);

    final d = ForgeLaunch.parse(const []);
    expect(d.workspace, isNull);
    expect(d.trails, isEmpty);
    expect(
      ForgeLaunch.parse(['rel.pdf']).documents.single,
      File('rel.pdf').absolute.path,
    );
  });
}
