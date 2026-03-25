import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'src/app.dart';
import 'src/test_app_module.dart';
import 'src/workspace_seed.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  final shell = DefaultShellApi.withDefaults(
    fileSystemSeed: workspaceSeed,
    appName: 'Forge Test IDE',
    navigatorKey: navigatorKey,
  );

  // Register modules.
  final registry = shell.modules as DefaultModuleRegistry;

  final shellModule = TomForgeShellModule();
  shellModule.activate(shell);
  registry.register(shellModule);

  final appModule = TestAppModule();
  appModule.activate(shell);
  registry.register(appModule);

  // Build application layout from module views.
  ForgeView viewById(String title) =>
      appModule.views.firstWhere((v) => v.title.value == title);

  final app = ForgeApplication(
    title: 'Forge Test IDE',
    layout: ApplicationLayout(
      leftPanel: PanelConfig(
        initialSize: 250,
        tabs: [
          PanelTabConfig(
            title: 'Explorer',
            icon: Icons.folder_outlined,
            sections: [viewById('Explorer')],
          ),
          PanelTabConfig(
            title: 'Search',
            icon: Icons.search,
            sections: [viewById('Search')],
          ),
        ],
      ),
      rightPanel: PanelConfig(
        initialSize: 220,
        tabs: [
          PanelTabConfig(
            title: 'Outline',
            icon: Icons.account_tree,
            sections: [viewById('Outline')],
          ),
        ],
      ),
      bottomPanel: PanelConfig(
        initialSize: 180,
        tabs: [
          PanelTabConfig(
            title: 'Problems',
            icon: Icons.error_outline,
            sections: [viewById('Problems')],
          ),
          PanelTabConfig(
            title: 'Output',
            icon: Icons.terminal,
            sections: [viewById('Output')],
          ),
        ],
      ),
      middlePanels: [const MiddlePanelConfig()],
    ),
  );

  runApp(ForgeTestApp(
    shell: shell,
    application: app,
    navigatorKey: navigatorKey,
  ));
}
