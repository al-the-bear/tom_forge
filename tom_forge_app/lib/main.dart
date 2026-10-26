import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';
import 'package:tom_file_system/io.dart';

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
  runApp(const ForgeLauncher()); // comment 
}

/// Launcher widget that manages workspace selection and app creation.
class ForgeLauncher extends StatefulWidget {
  const ForgeLauncher({super.key});
  @override
  State<ForgeLauncher> createState() => _ForgeLauncherState(); // comment added
}

class _ForgeLauncherState extends State<ForgeLauncher> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  DefaultShellApi? _shell;
  ForgeApplication? _application;
  bool _workspaceReady = false;

  void _initializeWithWorkspace(Directory workspaceDir) {
    unawaited(_initializeWithWorkspaceAsync(workspaceDir));
  }

  Future<void> _initializeWithWorkspaceAsync(Directory workspaceDir) async {
    final wsManager = DefaultWorkspaceStateManager();

    // detectWorkspaceRoot may walk up past the user-selected folder, which
    // on the macOS sandbox leaves us without read access. Only accept a
    // detected parent if we can actually read its contents; otherwise fall
    // back to the folder the user explicitly granted access to.
    String? detectedRoot;
    try {
      detectedRoot = await wsManager.detectWorkspaceRoot(workspaceDir.path);
      if (detectedRoot != null && detectedRoot != workspaceDir.path) {
        try {
          await Directory(detectedRoot).list(followLinks: false).first;
        } on StateError {
          // Directory is empty but readable — accept it.
        } catch (e) {
          debugPrint(
            '[tom_forge_app] cannot access detected root $detectedRoot: $e',
          );
          detectedRoot = null;
        }
      }
    } catch (e) {
      debugPrint('[tom_forge_app] detectWorkspaceRoot failed: $e');
      detectedRoot = null;
    }
    final effectiveDir =
        detectedRoot != null ? Directory(detectedRoot) : workspaceDir;

    try {
      await wsManager.initialize(effectiveDir.path);
    } catch (e) {
      debugPrint('[tom_forge_app] workspace initialize failed: $e');
    }
    try {
      await wsManager.suggestGitignore(effectiveDir.path);
    } catch (e) {
      debugPrint('[tom_forge_app] suggestGitignore failed: $e');
    }

    final prefs = ForgePreferencesService.instance;
    if (!prefs.isLoaded) {
      await prefs.load();
    }
    prefs.startupPreferences.lastWorkspacePath = effectiveDir.path;
    await prefs.save();

    final persistentStorage = PersistentModuleStorage(
      forgeDir: wsManager.forgeDirectoryPath,
    );

    // The local file system over the selected directory
    final realFs = TomLocalFileSystem(effectiveDir.path);

    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: realFs,
      appName: 'Tom Forge',
      navigatorKey: _navigatorKey,
      workspaceState: wsManager,
      storage: persistentStorage,
    );

    // Set the workspace root so file search and other features know where to look.
    (shell.systemState as DefaultSystemState)
        .setWorkspaceRootPath(effectiveDir.path);

    // Register modules
    final registry = shell.modules as DefaultModuleRegistry;

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);
    registry.register(shellModule);

    final appModule = ForgeAppModule(
      workspaceRootUri: effectiveDir.uri,
    );
    appModule.activate(shell);
    registry.register(appModule);

    // Website editor module (§9): contributes the embedded site preview, the
    // dev-server / generator control panel, and the content catalog browser.
    // It resolves tom.website-editor.yaml at the workspace root and disables
    // itself gracefully when that file is absent (load() surfaces the read
    // failure as an issue rather than throwing).
    final websiteModule = WebsiteEditorModule();
    websiteModule.activate(shell);
    registry.register(websiteModule);

    // Build application layout from module views
    ForgeView viewById(String title) =>
        appModule.views.firstWhere((v) => v.title.value == title);

    final app = ForgeApplication(
      title: 'Tom Forge',
      workspaceFolder: effectiveDir.path.split('/').last,
      layout: ApplicationLayout(
        leftPanel: PanelConfig(
          initialSize: 250,
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder_outlined,
              sections: [viewById('Explorer'), viewById('Revisions')],
            ),
            PanelTabConfig(
              title: 'Search',
              icon: Icons.search,
              sections: [viewById('Search')],
            ),
            PanelTabConfig(
              title: 'Website',
              icon: Icons.public,
              sections: [
                websiteModule.controlView!,
                websiteModule.contentView!,
                websiteModule.structureView!,
              ],
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
              title: 'Web Preview',
              icon: Icons.web,
              sections: [websiteModule.previewView!],
            ),
            PanelTabConfig(
              title: 'Terminal',
              icon: Icons.code,
              sections: [],
            ),
          ],
        ),
        middlePanels: [const MiddlePanelConfig()],
      ),
    );

    if (!mounted) {
      shell.dispose();
      return;
    }

    setState(() {
      _shell = shell;
      _application = app;
      _workspaceReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ForgeApp(
      shell: _shell ?? _createPlaceholderShell(),
      application: _application ?? _createPlaceholderApp(),
      navigatorKey: _navigatorKey,
      onWorkspaceSelected: _initializeWithWorkspace,
      workspaceReady: _workspaceReady,
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
