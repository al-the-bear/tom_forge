// Default-startup wiring for the website editor module.
//
// composeForgeSuite registers a [WebsiteEditorModule] on every Forge launch and places
// its four views (Preview / Control / Content / Structure) into the default
// layout. This guards two facts that make that safe:
//   1. The module exposes its four views individually for host placement.
//   2. Activation in a workspace WITHOUT a tom.website-editor.yaml does not
//      throw — activate() runs load() unawaited, so a missing/unreadable config
//      must settle into an error issue, never an unhandled zone error.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultModuleRegistry,
        DefaultShellApi,
        DefaultSystemState,
        TomForgeShellModule;
import 'package:tom_forge_code_editors/tom_forge_code_editors.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

void main() {
  group('Website editor default-startup wiring', () {
    late DefaultShellApi shell;

    setUp(() {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);
    });

    tearDown(() => shell.dispose());

    test('exposes its four views for host layout placement', () {
      final module = WebsiteEditorModule();
      module.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(module);

      expect(module.previewView, isNotNull);
      expect(module.controlView, isNotNull);
      expect(module.contentView, isNotNull);
      expect(module.structureView, isNotNull);
      expect(module.views, hasLength(4));
      expect(
        module.views.map((v) => v.title.value),
        containsAll(<String>['Preview', 'Control', 'Content', 'Structure']),
      );

      module.deactivate();
    });

    test('activates safely without a config file (no zone throw)', () async {
      final module = WebsiteEditorModule();
      module.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(module);

      // Let the unawaited load() kicked by activate() settle. If it threw, the
      // flutter_test zone would fail this test.
      await Future<void>.delayed(Duration.zero);

      // And the failure is surfaced as an issue, not a crash: the module stays
      // unloaded with at least one issue recorded.
      final loaded = await module.controller!.load();
      expect(loaded, isFalse);
      expect(module.controller!.isLoaded, isFalse);
      expect(module.controller!.issues, isNotEmpty);

      module.deactivate();
    });
  });

  // §6 self-registration: the website module contributes its config editor
  // through the standard `editors` getter, so opening files routes via
  // `ForgeEditor.canHandle` — the config file to the WebsiteConfigEditor, every
  // other YAML/Markdown file (incl. content files) to the standard editors. No
  // filename hand-wiring lives in forge_suite.dart.
  group('Website editor file-open routing', () {
    const validConfig = '''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/sites/ef"
''';
    final configUri = Uri.parse('file:///tom.website-editor.yaml');
    final contentYamlUri =
        Uri.parse('file:///content/components/button.yaml');

    late DefaultShellApi shell;

    setUp(() {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: {
          '/tom.website-editor.yaml': validConfig,
          '/content/components/button.yaml': 'id: button\nname: Button\n',
        },
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      // Workspace root must be set BEFORE the module activates, so it resolves
      // the config URI against `/` (mirrors composeForgeSuite's ordering).
      (shell.systemState as DefaultSystemState).setWorkspaceRootPath('/');
      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);
      final websiteModule = WebsiteEditorModule();
      websiteModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(websiteModule);
    });

    tearDown(() => shell.dispose());

    Future<ForgeEditor> openAndWait(Uri uri) async {
      shell.layout.openFile(uri);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final match =
            shell.systemState.openEditors.where((e) => e.uri == uri);
        if (match.isNotEmpty) return match.first;
      }
      fail('editor for $uri never opened');
    }

    test('the config file routes to the WebsiteConfigEditor', () async {
      final editor = await openAndWait(configUri);
      expect(editor, isA<WebsiteConfigEditor>());
    });

    test('a content .yaml routes to the standard YAML editor, not the config',
        () async {
      final editor = await openAndWait(contentYamlUri);
      expect(editor, isA<ForgeYamlEditor>(),
          reason: 'content yaml opens in a real YAML editor');
      expect(editor, isNot(isA<WebsiteConfigEditor>()),
          reason: 'the config editor must not hijack content yaml');
      expect(editor.uri, contentYamlUri,
          reason: 'the editor is bound to the content file, not the config');
    });
  });
}
