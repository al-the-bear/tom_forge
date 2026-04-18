import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'package:tom_forge_app/src/app.dart';
import 'package:tom_forge_app/src/forge_app_module.dart';
import 'package:tom_forge_app/src/workspace_seed.dart';

/// Phase E: Promotion to tom_forge_app
///
/// These tests verify that the promoted production app has identical
/// bootstrap/module composition to the staging app (tom_forge_ui_test).
void main() {
  group('Phase E - Production App Promotion', () {
    testWidgets('shell scaffold renders title bar', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: workspaceSeed,
        appName: 'Tom Forge',
        navigatorKey: navigatorKey,
      );

      final registry = shell.modules as DefaultModuleRegistry;
      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      registry.register(shellModule);
      final appModule = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
      appModule.activate(shell);
      registry.register(appModule);

      final app = ForgeApplication(title: 'Tom Forge');

      await tester.pumpWidget(
        ForgeApp(
          shell: shell,
          application: app,
          navigatorKey: navigatorKey,
          onWorkspaceSelected: (_) {},
          workspaceReady: true,
        ),
      );

      expect(find.text('Tom Forge'), findsOneWidget);
    });

    test(
      'layout opens seeded .txt file with markdown editor adapter',
      () async {
        final navigatorKey = GlobalKey<NavigatorState>();
        final shell = DefaultShellApi.withDefaults(
          fileSystemSeed: workspaceSeed,
          appName: 'Tom Forge',
          navigatorKey: navigatorKey,
        );

        final registry = shell.modules as DefaultModuleRegistry;
        final shellModule = TomForgeShellModule();
        shellModule.activate(shell);
        registry.register(shellModule);
        final appModule = ForgeAppModule(
          workspaceRootUri: Uri.parse('file:///'),
        );
        appModule.activate(shell);
        registry.register(appModule);

        shell.layout.openFile(Uri.parse('file:///doc/notes.txt'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final active = shell.systemState.activeEditor;
        expect(active, isNotNull);
        expect(active, isA<ForgeMdEditor>());
        expect(active!.uri.path, endsWith('/doc/notes.txt'));
      },
    );

    test('module actions include all required file/edit/view commands', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: workspaceSeed,
        appName: 'Tom Forge',
        navigatorKey: navigatorKey,
      );

      final appModule = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
      appModule.activate(shell);

      final actionIds = appModule.actions.map((a) => a.id).toSet();

      // Core file actions
      expect(actionIds, contains('file.save'));
      expect(actionIds, contains('file.saveAll'));
      expect(actionIds, contains('file.close'));
      expect(actionIds, contains('file.closeAll'));

      // Core edit actions
      expect(actionIds, contains('edit.undo'));
      expect(actionIds, contains('edit.redo'));
      expect(actionIds, contains('edit.findInFiles'));

      // Core view actions
      expect(actionIds, contains('view.toggleExplorer'));
      expect(actionIds, contains('view.toggleOutline'));
      expect(actionIds, contains('view.toggleProblems'));
      expect(actionIds, contains('view.toggleOutput'));
      expect(actionIds, contains('view.splitEditor'));

      // Help actions
      expect(actionIds, contains('help.about'));
    });

    test('module shortcuts bind all required key combinations', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: workspaceSeed,
        appName: 'Tom Forge',
        navigatorKey: navigatorKey,
      );

      final appModule = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
      appModule.activate(shell);

      final boundActionIds = appModule.shortcuts
          .map((s) => s.action.id)
          .toSet();

      // Concept-defined standard shortcuts bound by the app module.
      expect(boundActionIds, contains('file.saveAll'));
      expect(boundActionIds, contains('editor.find'));
      expect(boundActionIds, contains('editor.deleteLine'));
      expect(boundActionIds, contains('edit.undo'));
      expect(boundActionIds, contains('edit.redo'));
      expect(boundActionIds.length, greaterThanOrEqualTo(5));
    });

    test('module views include all required panels', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: workspaceSeed,
        appName: 'Tom Forge',
        navigatorKey: navigatorKey,
      );

      final appModule = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
      appModule.activate(shell);

      final viewTitles = appModule.views.map((v) => v.title.value).toSet();

      expect(viewTitles, contains('Explorer'));
      expect(viewTitles, contains('Outline'));
      expect(viewTitles, contains('Search'));
      expect(viewTitles, contains('Problems'));
      expect(viewTitles, contains('Output'));
    });

    test('module status bar items include cursor and language indicators', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: workspaceSeed,
        appName: 'Tom Forge',
        navigatorKey: navigatorKey,
      );

      final appModule = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
      appModule.activate(shell);

      final tooltips = appModule.statusBarItems.map((i) => i.tooltip).toSet();

      expect(tooltips, contains('Cursor Position'));
      expect(tooltips, contains('File Encoding'));
      expect(tooltips, contains('Language Mode'));
      expect(tooltips, contains('Problems'));
    });

    test('format document action rewrites active text content', () async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: {'/workspace/notes.md': 'alpha  \nbeta\t  '},
        appName: 'Tom Forge',
        navigatorKey: navigatorKey,
      );

      final registry = shell.modules as DefaultModuleRegistry;
      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      registry.register(shellModule);

      final appModule = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
      appModule.activate(shell);
      registry.register(appModule);

      shell.layout.openFile(Uri.parse('file:///workspace/notes.md'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final formatAction = appModule.actions.firstWhere(
        (action) => action.id == 'edit.formatDocument',
      );
      await formatAction.execute(const {});

      final active = shell.systemState.activeEditor;
      expect(active, isNotNull);
      expect(active!.getContent(), 'alpha\nbeta');

      shell.dispose();
    });
  });
}
