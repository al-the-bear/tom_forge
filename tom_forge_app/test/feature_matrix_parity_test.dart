import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    setUp(() {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      shellModule = TomForgeShellModule();
      (shell.modules as DefaultModuleRegistry).register(shellModule);
      shellModule.activate(shell);
    });

    tearDown(() {
      shell.dispose();
    });

    test('ForgeAppModule activates with views, actions, shortcuts, status bar', () {
      final module = ForgeAppModule(
        workspaceRootUri: Uri.parse('file:///workspace'),
      );
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);

      expect(module.views.length, greaterThanOrEqualTo(5),
          reason: 'Should have Explorer, Outline, Problems, Output, Search views');
      expect(module.actions.length, greaterThanOrEqualTo(12),
          reason: 'Should have file/edit/view/help actions');
      expect(module.shortcuts.length, greaterThanOrEqualTo(11),
          reason: 'Should have shortcut bindings for key actions');
      expect(module.statusBarItems.length, equals(4),
          reason: 'Should have cursor, encoding, language, diagnostics');

      module.deactivate();
    });

    test('ForgeAppModule deactivate clears all lists', () {
      final module = ForgeAppModule(
        workspaceRootUri: Uri.parse('file:///workspace'),
      );
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);

      expect(module.views, isNotEmpty);
      module.deactivate();

      expect(module.views, isEmpty);
      expect(module.actions, isEmpty);
      expect(module.shortcuts, isEmpty);
      expect(module.statusBarItems, isEmpty);
    });

    test('ForgeAppModule registers outline provider', () {
      final module = ForgeAppModule(
        workspaceRootUri: Uri.parse('file:///workspace'),
      );
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);

      final outlineMgr = shell.outline as DefaultOutlineManager;
      expect(outlineMgr.providers, isNotEmpty,
          reason: 'Outline provider should be registered by ForgeAppModule');

      module.deactivate();
    });

    test('ForgeAppModule registers file decoration provider', () {
      final module = ForgeAppModule(
        workspaceRootUri: Uri.parse('file:///workspace'),
      );
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);

      final decoMgr = shell.fileDecorations as DefaultFileDecorationManager;
      expect(decoMgr.providers, isNotEmpty,
          reason: 'Decoration provider should be registered by ForgeAppModule');

      module.deactivate();
    });

    test('ForgeAppModule uses module-scoped persistence', () {
      final module = ForgeAppModule(
        workspaceRootUri: Uri.parse('file:///workspace'),
      );
      (shell.modules as DefaultModuleRegistry).register(module);
      module.activate(shell);

      // After activation, the activation count should be stored.
      final store = shell.storage.forModule(module);
      expect(store.get('activationCount'), equals(1));

      // Second activation increments.
      module.deactivate();
      module.activate(shell);
      expect(store.get('activationCount'), equals(2));

      module.deactivate();
    });
  });
}
