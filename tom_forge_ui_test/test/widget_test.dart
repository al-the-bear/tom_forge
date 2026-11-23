import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultModuleRegistry,
        DefaultShellApi,
        ForgeApplication,
        TomForgeShellModule;
import 'package:tom_forge_plain_text_editor/tom_forge_plain_text_editor.dart'
    show ForgePlainTextEditor;

import 'package:tom_forge_ui_test/src/app.dart';
import 'package:tom_forge_ui_test/src/test_app_module.dart';
import 'package:tom_forge_ui_test/src/workspace_seed.dart';

/// Config with zero-duration debounces for synchronous test behavior.
const _testConfig = ForgeConfig(
  performance: ForgePerformanceConfig(
    diagnosticDebounceWindow: Duration.zero,
  ),
);

void main() {
  testWidgets('Shell scaffold renders title bar', (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: workspaceSeed,
      appName: 'Test',
      navigatorKey: navigatorKey,
      initialConfig: _testConfig,
    );

    final registry = shell.modules as DefaultModuleRegistry;
    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    registry.register(shellModule);
    final appModule = TestAppModule(workspaceRootUri: Uri.parse('file:///'));
    appModule.activate(shell);
    registry.register(appModule);

    shell.applications.add(
      ForgeApplication(id: 'forge-test-ide', title: 'Forge Test IDE'),
    );

    await tester.pumpWidget(ForgeTestApp(
      shell: shell,
      navigatorKey: navigatorKey,
      onWorkspaceSelected: (_) {},
    ));

    expect(find.text('Tom Forge'), findsOneWidget);
  });

  test('layout opens seeded .txt file with plain text editor', () async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: workspaceSeed,
      appName: 'Test',
      navigatorKey: navigatorKey,
      initialConfig: _testConfig,
    );

    final registry = shell.modules as DefaultModuleRegistry;
    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    registry.register(shellModule);
    final appModule = TestAppModule(workspaceRootUri: Uri.parse('file:///'));
    appModule.activate(shell);
    registry.register(appModule);

    shell.layout.openFile(Uri.parse('file:///doc/notes.txt'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final active = shell.systemState.activeEditor;
    expect(active, isNotNull);
    expect(active, isA<ForgePlainTextEditor>());
    expect(active!.uri.path, endsWith('/doc/notes.txt'));
  });
}
