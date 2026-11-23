import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultModuleRegistry,
        DefaultShellApi,
        ForgeApplication,
        ForgePreferencesService,
        ForgeShellComponents,
        MiddlePanelConfig,
        PanelConfig,
        PanelLayout,
        PanelTabConfig,
        TomForgeShellModule;
import 'package:tom_forge_terminal/tom_forge_terminal.dart';
import 'package:tom_forge_dart_editor/tom_forge_dart_editor.dart';
import 'package:tom_forge_md_editor/tom_forge_md_editor.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';
import 'package:tom_forge_platform_secrets/tom_forge_platform_secrets.dart';
import 'package:tom_forge_desktop_host/tom_forge_desktop_host.dart';
import 'package:tom_file_system/io.dart';

import 'src/app.dart';
import 'src/test_app_module.dart';

/// The desktop components the test IDE hands its shells: the terminal, the
/// code editors, the platform keychain and the desktop host, composed from
/// the shell parts.
final ForgeShellComponents _desktopComponents = forgeTerminalComponents
    .mergedWith(
      ForgeShellComponents(
        editorTypes: [
          forgeMarkdownEditorType,
          forgeDartEditorType,
          forgeYamlEditorType,
        ],
      ),
    )
    .mergedWith(forgePlatformSecretComponents)
    .mergedWith(forgeDesktopHostComponents);

void main(List<String> args) {
  // CLI bypass: pass workspace path as first argument to skip welcome dialog.
  final initialWorkspacePath =
      args.isNotEmpty && Directory(args.first).existsSync() ? args.first : null;
  runApp(ForgeTestLauncher(initialWorkspacePath: initialWorkspacePath));
}

/// Initial launcher widget that manages workspace selection and app creation.
class ForgeTestLauncher extends StatefulWidget {
  final String? initialWorkspacePath;

  const ForgeTestLauncher({super.key, this.initialWorkspacePath});

  @override
  State<ForgeTestLauncher> createState() => _ForgeTestLauncherState();
}

class _ForgeTestLauncherState extends State<ForgeTestLauncher> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  DefaultShellApi? _shell;

  @override
  void initState() {
    super.initState();
    // CLI bypass: if a workspace path was passed via args, skip welcome page.
    if (widget.initialWorkspacePath != null) {
      _initializeWithWorkspace(Directory(widget.initialWorkspacePath!));
    }
  }

  void _initializeWithWorkspace(Directory workspaceDir) async {
    // Walk-up detection: check if a parent directory has `.forge/`
    final wsManager = DefaultWorkspaceStateManager();
    final detectedRoot = await detectForgeWorkspaceRoot(workspaceDir.path);
    final effectiveDir = detectedRoot != null
        ? Directory(detectedRoot)
        : workspaceDir;

    // The local file system over the selected directory: the shell's, and
    // the workspace state's (.forge/) and module storage's.
    final realFs = TomLocalFileSystem(effectiveDir.path);
    await wsManager.initialize(realFs);
    await keepForgeStateOutOfGit(effectiveDir.path);

    // Save the workspace path to preferences for next-launch recovery.
    final prefs = ForgePreferencesService.instance;
    if (!prefs.isLoaded) await prefs.load();
    prefs.startupPreferences.lastWorkspacePath = effectiveDir.path;
    await prefs.save();

    // Module storage under .forge/state/modules/.
    final persistentStorage = await PersistentModuleStorage.open(realFs);

    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: realFs,
      appName: 'Forge Test IDE',
      navigatorKey: _navigatorKey,
      workspaceState: wsManager,
      storage: persistentStorage,
      components: _desktopComponents,
    );

    // Register modules
    final registry = shell.modules as DefaultModuleRegistry;

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    registry.register(shellModule);

    final appModule = TestAppModule(workspaceRootUri: effectiveDir.uri);
    appModule.activate(shell);
    registry.register(appModule);

    // Build application layout from module views
    ForgeView viewById(String title) =>
        appModule.views.firstWhere((v) => v.title.value == title);

    final workspaceName = effectiveDir.path.split('/').last;

    // Full IDE application with all panels
    final fullApp = ForgeApplication(
      id: 'full-ide-workspacename',
      title: 'Full IDE - $workspaceName',
      icon: Icons.code,
      layout: PanelLayout(
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
            PanelTabConfig(title: 'Terminal', icon: Icons.code, sections: []),
          ],
        ),
        middlePanels: [const MiddlePanelConfig()],
      ),
      isActive: true,
    );

    // Minimal application with just explorer
    final minimalApp = ForgeApplication(
      id: 'minimal-workspacename',
      title: 'Minimal - $workspaceName',
      icon: Icons.article_outlined,
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 200,
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder_outlined,
              sections: [viewById('Explorer')],
            ),
          ],
        ),
        rightPanel: const PanelConfig(initialSize: 0, tabs: []),
        bottomPanel: const PanelConfig(initialSize: 0, tabs: []),
        middlePanels: [const MiddlePanelConfig()],
      ),
    );

    // The registry keeps both; the last active one and any application
    // opened at run time come back from .forge/state/applications.json.
    shell.applications
      ..add(fullApp)
      ..add(minimalApp);
    await shell.restoreApplications();

    setState(() => _shell = shell);
  }

  @override
  Widget build(BuildContext context) {
    return ForgeTestApp(
      shell: _shell ?? _createPlaceholderShell(),
      navigatorKey: _navigatorKey,
      onWorkspaceSelected: _initializeWithWorkspace,
    );
  }

  DefaultShellApi _createPlaceholderShell() {
    return DefaultShellApi.withDefaults(
      fileSystemSeed: {},
      appName: 'Forge Test IDE',
      navigatorKey: _navigatorKey,
      components: _desktopComponents,
    );
  }
}
