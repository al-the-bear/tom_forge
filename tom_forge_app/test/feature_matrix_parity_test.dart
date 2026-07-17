import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'package:tom_forge_app/src/forge_app_module.dart';

/// Section 29 Row 12: Staging-to-production parity tests.
///
/// Verifies that [ForgeAppModule] has the same module composition as
/// [TestAppModule] — views, actions, shortcuts, status bar items,
/// providers, and module-scoped persistence.
void main() {
  group('Section 29 - ForgeAppModule parity', () {
    late DefaultShellApi shell;
    late TomForgeShellModule shellModule;

    ForgeAppModule activateModule() {
      final module = ForgeAppModule(
        workspaceRootUri: Uri.parse('file:///workspace'),
      );
      module.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(module);
      return module;
    }

    setUp(() {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);
    });

    tearDown(() {
      shell.dispose();
    });

    test('ForgeAppModule activates with views, actions, shortcuts, status bar', () {
      final module = activateModule();

      expect(module.views.length, greaterThanOrEqualTo(5),
          reason: 'Should have Explorer, Outline, Problems, Output, Search views');
      expect(module.actions.length, greaterThanOrEqualTo(12),
          reason: 'Should have file/edit/view/help actions');
      // Shortcut bindings are owned by TomForgeShellModule, not the app module
      // (see "Move all shortcuts into module system"). The app module relies on
      // the shell-provided bindings and contributes none of its own.
      expect(module.shortcuts, isEmpty,
          reason: 'App module delegates key bindings to TomForgeShellModule');
      expect(shellModule.shortcuts.length, greaterThanOrEqualTo(5),
          reason: 'Shell module provides the key-action shortcut bindings');
      expect(module.statusBarItems.length, equals(5),
          reason: 'cursor, encoding, language, diagnostics, notifications');

      module.deactivate();
    });

    test('ForgeAppModule deactivate clears all lists', () {
      final module = activateModule();

      expect(module.views, isNotEmpty);
      module.deactivate();

      expect(module.views, isEmpty);
      expect(module.actions, isEmpty);
      expect(module.shortcuts, isEmpty);
      expect(module.statusBarItems, isEmpty);
    });

    test('ForgeAppModule registers outline provider', () {
      final module = activateModule();

      final outlineMgr = shell.outline as DefaultOutlineManager;
      expect(outlineMgr.providers, isNotEmpty,
          reason: 'Outline provider should be registered by ForgeAppModule');

      module.deactivate();
    });

    test('ForgeAppModule registers file decoration provider', () {
      final module = activateModule();

      final decoMgr = shell.fileDecorations as DefaultFileDecorationManager;
      expect(decoMgr.providers, isNotEmpty,
          reason: 'Decoration provider should be registered by ForgeAppModule');

      module.deactivate();
    });

    test('ForgeAppModule uses module-scoped persistence', () {
      final module = activateModule();

      // After activation, the activation count should be stored.
      final store = shell.storage.forModule(module);
      expect(store.get('activationCount'), equals(1));

      // Second activation increments.
      module.deactivate();
      module.activate(shell);
      expect(store.get('activationCount'), equals(2));

      module.deactivate();
    });

    test('ForgeAppModule updates cursor status from active text editor', () async {
      final module = activateModule();

      final editor = ForgeTestTextEditor(
        module,
        document: ForgeTestDocument(
          uri: Uri.parse('file:///workspace/lib/main.dart'),
          content: 'void main() {}',
        ),
      );

      final state = shell.systemState as DefaultSystemState;
      state.addOpenEditor(editor);
      state.setActiveEditor(editor);
      await Future<void>.delayed(Duration.zero);

      editor.setCursorPosition(const ForgeTextPosition(line: 2, column: 3));
      await Future<void>.delayed(Duration.zero);

      expect(module.statusBarItems.first.text.value, equals('Ln 3, Col 4'));

      module.deactivate();
      editor.dispose();
    });

    test('ForgeAppModule persists editor context for storage wiring', () async {
      final module = activateModule();

      final editorUri = Uri.parse('file:///workspace/README.md');
      final editor = ForgeTestTextEditor(
        module,
        document: ForgeTestDocument(
          uri: editorUri,
          content: '# Workspace',
        ),
      );

      final state = shell.systemState as DefaultSystemState;
      state.addOpenEditor(editor);
      state.setActiveEditor(editor);
      state.setActiveMiddlePanelIndex(2);
      await Future<void>.delayed(Duration.zero);

      module.deactivate();
      await Future<void>.delayed(Duration.zero);

      final store = shell.storage.forModule(module);
      expect(store.get<String>('lastActiveEditorUri'), equals(editorUri.toString()));
      expect(store.get<int>('lastActiveMiddlePanel'), equals(2));
      expect(store.get<String>('lastKnownLanguage'), equals('Markdown'));

      editor.dispose();
    });
  });
}
