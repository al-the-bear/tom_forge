/// Composed editor workflows: several kinds of documents open at once in the
/// suite `composeForgeSuite` makes, on the running shell (`ForgeApp`), worked
/// on the way a user does — the integrated UX patterns
/// (`tom_forge/_agent_guidelines/integrated_ux_patterns.md`) across editors
/// of different packages, not one editor at a time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions, forgeTypingPause;
import 'package:tom_forge_app/forge_suite.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart'
    show ForgeMarkdownFileEditor;
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart'
    show ForgeYamlFileEditor;
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultShellApi, ForgePlainTextEditor, ForgeQuitObjection;

const _files = {
  '/ws/notes.md': '# Notes\n',
  '/ws/config.yaml': 'name: garden\n',
  '/ws/readme.txt': 'plain\n',
};

const _undo = StandardEditingActions.undoActionId;

Uri _uri(String name) => Uri.parse('file:///ws/$name');

/// The suite on the running shell, its tom_forge application shown.
Future<ForgeSuite> _mount(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final navigatorKey = GlobalKey<NavigatorState>();
  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: _files,
    appName: 'composed workflows',
    navigatorKey: navigatorKey,
  );
  // The scaffold disposes the shell when the app unmounts.
  final suite = (await tester.runAsync(
    () => composeForgeSuite(
      shell: shell,
      workspaceRoot: '/ws',
      navigatorKey: navigatorKey,
      restoreApplications: false,
    ),
  ))!;
  await tester.pumpWidget(
    ForgeApp(
      shell: shell,
      navigatorKey: navigatorKey,
      onWorkspaceSelected: (_) {},
      workspaceReady: true,
    ),
  );
  await tester.pumpAndSettle();
  return suite;
}

/// Opens [name] — or, when it is open, activates its editor (P4) — and
/// waits until its editor is the active one and shown.
Future<T> _open<T extends ForgeEditor>(
  WidgetTester tester,
  ForgeSuite suite,
  String name,
) async {
  final uri = _uri(name);
  suite.shell.layout.openFile(uri);
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    final active = suite.shell.systemState.activeEditor;
    if (active != null && active.uri == uri) {
      await tester.pump();
      return active as T;
    }
  }
  fail('$name never became the active editor');
}

/// The three documents, open on the shell and each edited once.
Future<
  (
    ForgeSuite,
    ForgeMarkdownFileEditor,
    ForgeYamlFileEditor,
    ForgePlainTextEditor,
  )
>
_threeEdited(WidgetTester tester) async {
  final suite = await _mount(tester);
  final md = await _open<ForgeMarkdownFileEditor>(tester, suite, 'notes.md');
  md.controller
    ..edit('# Notes\n\nRoses.\n')
    ..flush();
  final yaml = await _open<ForgeYamlFileEditor>(tester, suite, 'config.yaml');
  yaml.controller
    ..setValue(['name'], 'orchard')
    ..flush();
  final text = await _open<ForgePlainTextEditor>(tester, suite, 'readme.txt');
  text.insertText('more ');
  await tester.pump(forgeTypingPause);
  return (suite, md, yaml, text);
}

void main() {
  testWidgets('WF-1: with three kinds of documents edited, the shell\'s Undo '
      'undoes the active document only; activating another undoes that '
      'one', (tester) async {
    final (suite, md, yaml, text) = await _threeEdited(tester);
    final shell = suite.shell;
    expect(
      shell.systemState.dirtyEditors,
      unorderedEquals(<ForgeEditor>[md, yaml, text]),
    );

    await _open<ForgeEditor>(tester, suite, 'notes.md');
    expect(shell.executeAction(_undo), isTrue);
    await tester.pump();
    expect(md.controller.markdown, '# Notes\n');
    expect(md.isDirty.value, isFalse, reason: 'back to the saved text');
    expect(yaml.controller.yamlText, 'name: orchard\n', reason: 'untouched');
    expect(text.session.text, 'more plain\n', reason: 'untouched');

    await _open<ForgeEditor>(tester, suite, 'config.yaml');
    expect(shell.executeAction(_undo), isTrue);
    await tester.pump();
    expect(yaml.controller.yamlText, 'name: garden\n');
    expect(md.controller.markdown, '# Notes\n');
    expect(shell.systemState.dirtyEditors, [
      text,
    ], reason: 'only the document still edited is unsaved');
    await tester.pump(forgeTypingPause);
  });

  testWidgets('WF-2: quitting asks once, naming exactly the unsaved '
      'documents; declining keeps everything; with every edit undone it asks '
      'nothing', (tester) async {
    final (suite, md, yaml, text) = await _threeEdited(tester);
    final shell = suite.shell;
    final asked = <List<ForgeQuitObjection>>[];
    shell.applications.confirmQuit = (objections) async {
      asked.add(objections);
      return false;
    };

    expect(await shell.applications.quit(), isFalse);
    expect(asked, hasLength(1), reason: 'one question for everything');
    expect(
      asked.single.expand((o) => o.unsavedEditors),
      unorderedEquals(<ForgeEditor>[md, yaml, text]),
    );
    expect(shell.systemState.openEditors, containsAll([md, yaml, text]));

    for (final name in ['notes.md', 'config.yaml', 'readme.txt']) {
      await _open<ForgeEditor>(tester, suite, name);
      expect(shell.executeAction(_undo), isTrue, reason: name);
      await tester.pump();
    }
    expect(shell.systemState.dirtyEditors, isEmpty);
    expect(await shell.applications.quit(), isTrue);
    expect(asked, hasLength(1), reason: 'nothing objects: no question');
    await tester.pump(forgeTypingPause);
  });

  testWidgets('WF-3: Save writes the active document to its file and leaves '
      'the other edited documents unsaved', (tester) async {
    final (suite, md, yaml, text) = await _threeEdited(tester);
    final shell = suite.shell;

    await _open<ForgeEditor>(tester, suite, 'notes.md');
    expect(shell.executeAction('file.save'), isTrue);
    for (var i = 0; i < 20 && md.isDirty.value; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(md.isDirty.value, isFalse);
    expect(
      await tester.runAsync(() => shell.fileSystem.readText(_uri('notes.md'))),
      '# Notes\n\nRoses.\n',
    );
    expect(
      await tester.runAsync(
        () => shell.fileSystem.readText(_uri('config.yaml')),
      ),
      'name: garden\n',
      reason: 'an unsaved document is not written',
    );
    expect(
      shell.systemState.dirtyEditors,
      unorderedEquals(<ForgeEditor>[yaml, text]),
    );
    await tester.pump(forgeTypingPause);
  });
}
