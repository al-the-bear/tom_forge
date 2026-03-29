import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'src/app.dart';
import 'src/forge_app_module.dart';

void main() {
  if (Platform.isLinux) {
    // Linux WebView defaults to software rendering in the local plugin fork.
    debugPrint(
      '[tom_forge_app] Linux WebView defaults to software rendering. '
      'Set FLUTTER_INAPPWEBVIEW_LINUX_FORCE_GL=1 to force hardware mode for diagnostics.',
    );
  }
  runApp(const ForgeLauncher());
}

/// Launcher widget that manages workspace selection and app creation.
class ForgeLauncher extends StatefulWidget {
  const ForgeLauncher({super.key});

  @override
  State<ForgeLauncher> createState() => _ForgeLauncherState();
}

class _ForgeLauncherState extends State<ForgeLauncher> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  DefaultShellApi? _shell;
  ForgeApplication? _application;

  void _initializeWithWorkspace(Directory workspaceDir) {
    // Create real file system backed by the selected directory
    final realFs = RealFileSystem(rootDirectory: workspaceDir);

    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: realFs,
      appName: 'Tom Forge',
      navigatorKey: _navigatorKey,
    );

    // Register modules
    final registry = shell.modules as DefaultModuleRegistry;

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    registry.register(shellModule);

    final appModule = ForgeAppModule(
      workspaceRootUri: workspaceDir.uri,
    );
    appModule.activate(shell);
    registry.register(appModule);

    // Build application layout from module views
    ForgeView viewById(String title) =>
        appModule.views.firstWhere((v) => v.title.value == title);

    final app = ForgeApplication(
      title: 'Tom Forge - ${workspaceDir.path.split('/').last}',
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

    setState(() {
      _shell = shell;
      _application = app;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ForgeApp(
      shell: _shell ?? _createPlaceholderShell(),
      application: _application ?? _createPlaceholderApp(),
      navigatorKey: _navigatorKey,
      onWorkspaceSelected: _initializeWithWorkspace,
    );
  }

  DefaultShellApi _createPlaceholderShell() {
    return DefaultShellApi.withDefaults(
      fileSystemSeed: {},
      appName: 'Tom Forge',
      navigatorKey: _navigatorKey,
    );
  }

  ForgeApplication _createPlaceholderApp() {
    return ForgeApplication(
      title: 'Tom Forge',
      layout: const ApplicationLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );
  }
}
