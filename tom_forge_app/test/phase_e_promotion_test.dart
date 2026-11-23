import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultModuleRegistry,
        DefaultShellApi,
        ForgeApplication,
        TomForgeShellModule;
import 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart'
    show ForgePlainTextEditor;

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

      shell.applications.add(
        ForgeApplication(id: 'tom-forge', title: 'Tom Forge'),
      );

      await tester.pumpWidget(
        ForgeApp(
          shell: shell,
          navigatorKey: navigatorKey,
          onWorkspaceSelected: (_) {},
          workspaceReady: true,
        ),
      );

      expect(find.text('Tom Forge'), findsOneWidget);
    });

    test(
      'layout opens seeded .txt file with the plain-text fallback editor',
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

        // Markdown editor only claims .md/.markdown; a .txt file has no
        // dedicated handler and therefore opens in the plain-text fallback.
        final active = shell.systemState.activeEditor;
        expect(active, isNotNull);
        expect(active, isA<ForgePlainTextEditor>());
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

    test('shell module binds all required key combinations', () {
      final navigatorKey = GlobalKey<NavigatorState>();
      final shell = DefaultShellApi.withDefaults(
        fileSystemSeed: workspaceSeed,
        appName: 'Tom Forge',
        navigatorKey: navigatorKey,
      );

      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      final appModule = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
      appModule.activate(shell);

      // Key bindings live on the shell module; the app module owns none.
      expect(appModule.shortcuts, isEmpty);

      final boundActionIds = shellModule.shortcuts
          .map((s) => s.action.id)
          .toSet();

      // Shell-provided standard shortcuts.
      expect(boundActionIds, contains('forge.saveAll'));
      expect(boundActionIds, contains('forge.commandPalette'));
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
