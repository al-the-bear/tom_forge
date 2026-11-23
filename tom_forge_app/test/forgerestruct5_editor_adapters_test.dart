// The panel shell opens YAML, Markdown and Dart files with the editor
// adapters, each a package of its own on the kit (forgerestruct5): the shell
// takes their editor types (ForgeKitEditorType) through its components, and
// each editor reaches the shell through the kit API its module hands it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultModuleRegistry,
        DefaultShellApi,
        ForgeShellComponents,
        TomForgeShellModule;
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seed = {
    '/workspace/config.yaml': 'name: forge\nversion: 1\n',
    '/workspace/short.yml': 'a: 1\n',
    '/workspace/notes.md': '# Notes\n\nText.\n',
    '/workspace/readme.markdown': '# Readme\n',
    '/workspace/main.dart': 'void main() {}\n',
  };

  /// A shell given only the three adapters' editor types, with the shell's
  /// own module registered and activated (what owns the built-in types).
  (DefaultShellApi, TomForgeShellModule) shellWithAdapters() {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: seed,
      appName: 'Adapters',
      navigatorKey: GlobalKey<NavigatorState>(),
      components: ForgeShellComponents(
        editorTypes: [
          forgeMarkdownEditorType,
          forgeDartEditorType,
          forgeYamlEditorType,
        ],
      ),
    );
    final module = TomForgeShellModule();
    (shell.modules as DefaultModuleRegistry).register(module);
    module.activate(shell);
    return (shell, module);
  }

  Future<ForgeEditor> open(DefaultShellApi shell, String path) async {
    shell.layout.openFile(Uri.parse('file://$path'));
    // The layout controller reads the file asynchronously.
    for (var i = 0; i < 50; i++) {
      final active = shell.systemState.activeEditor;
      if (active != null && active.uri.path == path) return active;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('$path did not open');
  }

  group('forgerestruct5: the shell opens each kind with its adapter', () {
    final cases = <String, (TypeMatcher<ForgeEditor>, String)>{
      '/workspace/config.yaml': (isA<ForgeYamlEditor>(), 'yaml'),
      '/workspace/short.yml': (isA<ForgeYamlEditor>(), 'yaml'),
      '/workspace/notes.md': (isA<ForgeMdEditor>(), 'md'),
      '/workspace/readme.markdown': (isA<ForgeMdEditor>(), 'md'),
      '/workspace/main.dart': (isA<ForgeDartEditor>(), 'dart'),
    };
    for (final MapEntry(key: path, value: (matcher, typeId)) in cases.entries) {
      test('$path opens in the $typeId adapter, wired to the shell', () async {
        final (shell, module) = shellWithAdapters();
        final editor = await open(shell, path);
        expect(editor, matcher);
        expect(forgeEditorTypeIdOf(editor), typeId);
        expect(editor.getContent(), isNotNull);
        // The adapter belongs to the shell's own module and reaches the
        // shell through the kit API that module was activated with.
        final (owner, api) = switch (editor) {
          final ForgeYamlEditor e => (e.module, e.kitApi),
          final ForgeMdEditor e => (e.module, e.kitApi),
          final ForgeDartEditor e => (e.module, e.kitApi),
          _ => (null, null),
        };
        expect(owner, same(module));
        expect(api, same(shell));
        shell.dispose();
      });
    }

    test('without the adapters the shell opens them as plain text', () async {
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: seed,
        appName: 'Bare',
        navigatorKey: GlobalKey<NavigatorState>(),
        components: const ForgeShellComponents(),
      );
      final module = TomForgeShellModule();
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);
      final editor = await open(shell, '/workspace/config.yaml');
      expect(editor, isNot(isA<ForgeYamlEditor>()));
      expect(forgeEditorTypeIdOf(editor), 'plaintext');
      shell.dispose();
    });

    test('the Dart editors of a layout read the summaries set for it', () {
      final (shell, _) = shellWithAdapters();
      expect(
        ForgeDartSummariesByHost.of(shell.layout).sdkSummary,
        ForgeDartSummaryAssets.root.sdkSummary,
      );
      final assets = ForgeDartSummaryAssets.ofPackage('tom_forge_app');
      ForgeDartSummariesByHost.set(shell.layout, assets);
      expect(ForgeDartSummariesByHost.of(shell.layout), same(assets));
      shell.dispose();
    });
  });

  group('forgerestruct5: an editor type works without the shell', () {
    test('a kit host makes a YAML editor bound to its API', () {
      final api = DefaultKitApi(
        editorHost: _NoEditorHost(),
        fileSystem: TomMemoryFileSystem(seed: const {}),
      );
      final module = _KitModule();
      final editor = forgeYamlEditorType.create(
        ForgeKitEditorRequest(
          uri: Uri.parse('file:///workspace/a.yaml'),
          content: 'a: 1\n',
          module: module,
          api: api,
        ),
      );
      expect(editor, isA<ForgeYamlEditor>());
      expect((editor as ForgeYamlEditor).kitApi, same(api));
      expect(editor.getContent(), 'a: 1\n');
      expect(
        forgeYamlEditorType.opensByDefault(Uri.parse('file:///x/B.YML')),
        isTrue,
      );
      expect(
        forgeYamlEditorType.opensByDefault(Uri.parse('file:///x/b.md')),
        isFalse,
      );
      editor.dispose();
    });
  });
}

class _KitModule extends ForgeKitModule {
  @override
  String get displayName => 'Kit module';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

class _NoEditorHost implements ForgeEditorHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
