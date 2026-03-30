import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'src/app.dart';
import 'src/test_app_module.dart';

void main() => runApp(const ForgeTestLauncher());

/// Initial launcher widget that manages workspace selection and app creation.
class ForgeTestLauncher extends StatefulWidget {
  const ForgeTestLauncher({super.key});

  @override
  State<ForgeTestLauncher> createState() => _ForgeTestLauncherState();
}

class _ForgeTestLauncherState extends State<ForgeTestLauncher> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  DefaultShellApi? _shell;
  ForgeApplication? _application;

  void _initializeWithWorkspace(Directory workspaceDir) async {
    // Walk-up detection: check if a parent directory has `.forge/`
    final wsManager = DefaultWorkspaceStateManager();
    final detectedRoot =
        await wsManager.detectWorkspaceRoot(workspaceDir.path);
    final effectiveDir =
        detectedRoot != null ? Directory(detectedRoot) : workspaceDir;

    // Create real file system backed by the selected directory
    final realFs = RealFileSystem(rootDirectory: effectiveDir);

    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: realFs,
      appName: 'Forge Test IDE',
      navigatorKey: _navigatorKey,
      workspaceState: wsManager,
    );

    // Initialize workspace state (.forge/ directory)
    await wsManager.initialize(effectiveDir.path);
    await wsManager.suggestGitignore(effectiveDir.path);

    // Register modules
    final registry = shell.modules as DefaultModuleRegistry;

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    registry.register(shellModule);

    final appModule = TestAppModule(
      workspaceRootUri: effectiveDir.uri,
    );
    appModule.activate(shell);
    registry.register(appModule);

    // Build application layout from module views
    ForgeView viewById(String title) =>
        appModule.views.firstWhere((v) => v.title.value == title);

    final app = ForgeApplication(
      title: 'Forge Test IDE - ${effectiveDir.path.split('/').last}',
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
            PanelTabConfig(
              title: 'Terminal',
              icon: Icons.code,
              sections: [viewById('Terminal')],
            ),
          ],
        ),
        middlePanels: [const MiddlePanelConfig()],
      ),
    );

    setState(() {
      _shell = shell;
      _application = app;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ForgeTestApp(
      shell: _shell ?? _createPlaceholderShell(),
      application: _application ?? _createPlaceholderApp(),
      navigatorKey: _navigatorKey,
      onWorkspaceSelected: _initializeWithWorkspace,
    );
  }

  DefaultShellApi _createPlaceholderShell() {
    return DefaultShellApi.withDefaults(
      fileSystemSeed: {},
      appName: 'Forge Test IDE',
      navigatorKey: _navigatorKey,
    );
  }

  ForgeApplication _createPlaceholderApp() {
    return ForgeApplication(
      title: 'Forge Test IDE',
      layout: const ApplicationLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );
  }
}
