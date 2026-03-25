import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'package:tom_forge_ui_test/src/app.dart';
import 'package:tom_forge_ui_test/src/test_app_module.dart';
import 'package:tom_forge_ui_test/src/workspace_seed.dart';

void main() {
  testWidgets('Shell scaffold renders title bar', (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: workspaceSeed,
      appName: 'Test',
      navigatorKey: navigatorKey,
    );

    final registry = shell.modules as DefaultModuleRegistry;
    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    registry.register(shellModule);
    final appModule = TestAppModule();
    appModule.activate(shell);
    registry.register(appModule);

    final app = ForgeApplication(title: 'Forge Test IDE');

    await tester.pumpWidget(ForgeTestApp(
      shell: shell,
      application: app,
      navigatorKey: navigatorKey,
    ));

    expect(find.text('Forge Test IDE'), findsOneWidget);
  });
}
