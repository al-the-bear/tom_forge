/// The command line of Tom Forge's own app ([ForgeLaunch]): the folder, the
/// files to open, the trails.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_app/forge_suite.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  test('FL-1: --workspace, files and --trail are read; without a folder the '
      'first file\'s is taken', () {
    final a = ForgeLaunch.parse([
      '--workspace=/ws',
      '/ws/docs/a.pdf',
      '--trail=pdf, office,other',
      '-v',
    ]);
    expect(a.workspace!.path, '/ws');
    expect(a.documents, ['/ws/docs/a.pdf']);
    expect(a.trails, {'pdf', 'office', 'other'});

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

  test('FL-2: the files named on the command line open with the user\'s '
      'file-type defaults applied', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.forge.files.typeDefaults':
          '{"docx":"office.zetaoffice","pdf":"pdf.pdfjs"}',
    });
    final prefs = ForgePreferencesService();
    await prefs.load();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'/docs/notes.txt': 'notes'},
      appName: 'FL-2',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    addTearDown(shell.dispose);
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/',
      restoreApplications: false,
    );
    final layout = shell.layout as DefaultLayoutController;
    expect(layout.getFileTypeDefaultEditor('docx'), isNull);
    const ForgeLaunch(
      documents: ['/docs/notes.txt'],
    ).openDocuments(suite, preferences: prefs);
    expect(layout.getFileTypeDefaultEditor('docx'), 'office.zetaoffice');
    expect(layout.getFileTypeDefaultEditor('pdf'), 'pdf.pdfjs');
  });
}
