/// Tom Forge opens files in the combined file editors (qim_none-5).
///
/// `composeForgeSuite` registers `ForgeFileEditorsModule` after the
/// extensions' modules: Markdown, YAML, todo files, `.env` and other text open
/// in the editor of their kind over a `ForgeFileSession`, the module's own
/// editors. It leaves `tom.website-editor.yaml` to the website module's
/// config editor, Dart files to the shell's Dart editor, an extension the user
/// gave a default editor to that editor, and takes an extension's builder in
/// place of Forge's for a kind. Each editor as the suite's module makes it
/// passes Forge's undo conformance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_app/forge_suite.dart';
import 'package:tom_forge_file_editors_testing/tom_forge_file_editors_testing.dart';
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultModuleRegistry, DefaultShellApi, TomForgeShellModule;
import 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart'
    show ForgePlainTextEditor;
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_md_editor_testing/tom_forge_md_editor_testing.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';
import 'package:tom_forge_yaml_editor_testing/tom_forge_yaml_editor_testing.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _websiteConfig = '''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/sites/ef"
''';

const _todos = '''
todos:
  - id: plant-roses
    title: Plant the roses
    status: not-started
''';

const _files = {
  '/ws/notes.md': '# Notes\n',
  '/ws/config.yaml': 'name: garden\n',
  '/ws/plan.todo.yaml': _todos,
  '/ws/.env': 'API_KEY=secret\n',
  '/ws/readme.txt': 'plain text\n',
  '/ws/data.xyz': 'an unknown kind\n',
  '/ws/Makefile': 'all:\n',
  '/ws/main.dart': 'void main() {}\n',
  '/ws/tom.website-editor.yaml': _websiteConfig,
};

Uri _uri(String name) => Uri.parse('file:///ws/$name');

Future<ForgeSuite> _suite({
  List<ForgeSuiteExtension> extensions = const [],
}) async {
  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: _files,
    appName: 'qim_none-5',
    navigatorKey: GlobalKey<NavigatorState>(),
  );
  addTearDown(shell.dispose);
  final suite = await composeForgeSuite(
    shell: shell,
    workspaceRoot: '/ws',
    extensions: extensions,
    restoreApplications: false,
  );
  // The website module reads its config before its config editor exists.
  await suite.websiteModule.controller?.load();
  return suite;
}

Future<ForgeEditor> _open(ForgeSuite suite, String name) async {
  final uri = _uri(name);
  suite.shell.layout.openFile(uri);
  for (var i = 0; i < 100; i++) {
    final open = suite.shell.systemState.openEditors.where((e) => e.uri == uri);
    if (open.isNotEmpty) return open.first;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('$name never opened');
}

void main() {
  group('QIMN5 the suite opens files in the combined editors', () {
    test('QIMN5-1: Markdown, YAML, a todo file, .env and text open in the '
        'editor of their kind, the file editors module\'s, over a file '
        'session', () async {
      final suite = await _suite();
      final module = suite.fileEditorsModule;
      expect(suite.shell.modules.allModules, contains(module));

      final markdown = await _open(suite, 'notes.md');
      final yaml = await _open(suite, 'config.yaml');
      final todo = await _open(suite, 'plan.todo.yaml');
      final env = await _open(suite, '.env');
      final text = await _open(suite, 'readme.txt');
      expect(markdown, isA<ForgeMarkdownFileEditor>());
      expect(yaml, isA<ForgeYamlFileEditor>());
      expect(todo, isA<ForgeTodoFileEditor>());
      expect(env, isA<ForgeEnvFileEditor>());
      expect(text, isA<ForgePlainTextEditor>());
      expect(module.editors, containsAll([markdown, yaml, todo, env, text]));
      final fs = suite.shell.fileSystem;
      expect(
        (markdown as ForgeMarkdownFileEditor).session.path,
        fs.pathOf(_uri('notes.md')),
      );
      expect(
        (text as ForgePlainTextEditor).session.path,
        fs.pathOf(_uri('readme.txt')),
      );

      // Opening a file already open shows it again.
      expect(await _open(suite, 'notes.md'), same(markdown));
      expect(
        suite.shell.systemState.openEditors.where((e) => e.uri == markdown.uri),
        hasLength(1),
      );
    });

    test('QIMN5-1b: a .txt file, a file of an unknown extension and one '
        'without an extension open in the plain-text adapter '
        '(tom_forge_plain_text_editor), over a file session, in the suite and '
        'in the shell\'s own fallback', () async {
      final suite = await _suite();
      for (final name in ['readme.txt', 'data.xyz', 'Makefile']) {
        final editor = await _open(suite, name);
        expect(editor, isA<ForgePlainTextEditor>(), reason: name);
        expect(
          (editor as ForgePlainTextEditor).editorTypeId,
          ForgePlainTextEditor.typeId,
        );
        expect(editor.session.path, suite.shell.fileSystem.pathOf(_uri(name)));
      }

      // The shell alone (no file editors module): its fallback is the same
      // adapter, reading the file through its own session.
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: _files,
        appName: 'qim_none-5 shell',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      addTearDown(shell.dispose);
      final shellModule = TomForgeShellModule()..activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);
      for (final name in ['readme.txt', 'data.xyz']) {
        shell.layout.openFile(_uri(name));
        ForgeEditor? open;
        for (var i = 0; i < 100 && open == null; i++) {
          open = shell.systemState.openEditors
              .where((e) => e.uri == _uri(name))
              .firstOrNull;
          if (open == null) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }
        expect(open, isA<ForgePlainTextEditor>(), reason: name);
        expect((open as ForgePlainTextEditor).kitApi, same(shell));
      }
    });

    // One open per test, the test ending with it: the website config editor
    // keeps working after it opens (the YAML tree), which a test does not
    // wait out.
    test(
      'QIMN5-2a: the website config stays the website module\'s editor',
      () async {
        final suite = await _suite();
        final config = await _open(suite, 'tom.website-editor.yaml');
        expect(config, isA<WebsiteConfigEditor>());
        expect(suite.fileEditorsModule.editors, isNot(contains(config)));
      },
    );

    test(
      'QIMN5-2b: an extension the user gave a default editor opens in it',
      () async {
        final suite = await _suite();
        suite.shell.setFileTypeDefault('.txt', 'md');
        final text = await _open(suite, 'readme.txt');
        expect(text, isA<ForgeMdEditor>());
        expect(
          suite.fileEditorsModule.editors,
          isNot(contains(text)),
          reason: 'the user\'s default editor wins',
        );
      },
    );

    test('QIMN5-2c: the file editors leave a Dart file to the shell\'s Dart '
        'editor', () async {
      final suite = await _suite();
      // The rule itself: the module makes no editor for it, so the open falls
      // through to the shell, whose Dart editor has the file (its analysis
      // keeps the test's isolate busy, so it is not opened here).
      expect(suite.fileEditorsModule.editorFor(_uri('main.dart')), isNull);
      expect(suite.fileEditorsModule.openUri(_uri('main.dart')), isFalse);
      expect(suite.fileEditorsModule.editorFor(_uri('readme.txt')), isNotNull);
    });

    test(
      'QIMN5-3: an extension\'s builder replaces Forge\'s editor of a kind',
      () async {
        ForgeFileSessionProbe? built;
        final suite = await _suite(
          extensions: [
            ForgeSuiteExtension(
              fileEditorBuilders: (_) => {
                forgeMarkdownFileKind.id: (session, _, shellModule) {
                  built = ForgeFileSessionProbe(session.path);
                  return ForgePlainTextEditor(
                    session: session,
                    module: shellModule,
                  );
                },
              },
            ),
          ],
        );
        final markdown = await _open(suite, 'notes.md');
        expect(built?.path, suite.shell.fileSystem.pathOf(_uri('notes.md')));
        expect(markdown, isA<ForgePlainTextEditor>());
        expect(markdown, isNot(isA<ForgeMarkdownFileEditor>()));
        expect(
          await _open(suite, 'config.yaml'),
          isA<ForgeYamlFileEditor>(),
          reason: 'the other kinds stay Forge\'s',
        );
      },
    );
  });

  // Each editor as the suite's file editors module makes it, under Forge's
  // undo conformance: a module like the suite's over a shell holding the file.
  T made<T extends ForgeEditor>(String name, String saved) {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: {'/ws/$name': saved},
      appName: 'qim_none-5 conformance',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final shellModule = TomForgeShellModule()..activate(shell);
    (shell.modules as DefaultModuleRegistry).register(shellModule);
    final module = ForgeFileEditorsModule(
      fileKinds: ForgeFileKindRegistry(forgeSuiteFileKinds),
    )..activate(shell);
    final editor = module.editorFor(_uri(name))! as T;
    if (editor case final ForgeMarkdownFileEditor e) {
      e.session.adoptText(saved);
    } else if (editor case final ForgeYamlFileEditor e) {
      e.session.adoptText(saved);
    } else if (editor case final ForgePlainTextEditor e) {
      e.session.adoptText(saved);
    } else if (editor case final ForgeEnvFileEditor e) {
      e.session.adoptText(saved);
    } else if (editor case final ForgeTodoFileEditor e) {
      e.session.adoptText(saved);
    }
    return editor;
  }

  runForgeUndoConformance(
    'QIMN5-4 Markdown (suite)',
    (saved) => ForgeMarkdownFileSubject(made('notes.md', saved)),
  );
  runForgeUndoConformance(
    'QIMN5-4 YAML (suite)',
    (saved) => ForgeYamlFileSubject(made('config.yaml', saved)),
  );
  runForgeUndoConformance(
    'QIMN5-4 text (suite)',
    (saved) => ForgeTextFileSubject(made('readme.txt', saved)),
  );
  runForgeUndoConformance(
    'QIMN5-4 .env (suite)',
    (saved) => ForgeEnvFileSubject(made('.env', saved)),
  );
  runForgeUndoConformance(
    'QIMN5-4 todo file (suite)',
    (saved) => ForgeTodoFileSubject(made('plan.todo.yaml', saved)),
  );
}

/// What an extension's builder saw.
class ForgeFileSessionProbe {
  ForgeFileSessionProbe(this.path);
  final String path;
}
