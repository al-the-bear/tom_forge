import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_file_system/io.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

import 'app.dart';
import 'forge_app_module.dart';

/// What a host adds to Tom Forge: modules activated and registered after
/// Forge's own, and applications added after the tom_forge application.
///
/// Both are made from the composed [ForgeSuite], so an extension's
/// application can lay out views of Forge's modules as well as its own.
class ForgeSuiteExtension {
  const ForgeSuiteExtension({this.modules, this.applications});

  /// The extension's modules; the suite activates and registers each.
  final List<ForgeModule> Function(ForgeSuite suite)? modules;

  /// The extension's applications, added to `shell.applications` in order.
  final List<ForgeApplication> Function(ForgeSuite suite)? applications;
}

/// Tom Forge composed on a shell: its modules, its application, and what the
/// extensions added.
class ForgeSuite {
  ForgeSuite._({
    required this.shell,
    required this.navigatorKey,
    required this.workspaceRoot,
    required this.shellModule,
    required this.appModule,
    required this.websiteModule,
  });

  final DefaultShellApi shell;

  /// The navigator the shell's dialogs are routed through, for an extension
  /// module that raises its own; null when the composer was given none.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The workspace folder the suite edits.
  final String workspaceRoot;

  final TomForgeShellModule shellModule;
  final ForgeAppModule appModule;
  final WebsiteEditorModule websiteModule;

  /// The tom_forge application (Forge's own panel layout).
  late final ForgeApplication forgeApplication;

  /// The modules the extensions added, in order.
  final List<ForgeModule> extensionModules = [];

  /// The applications the extensions added, in order.
  final List<ForgeApplication> extensionApplications = [];

  void _register(ForgeModule module) {
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
  }
}

/// The id of the tom_forge application.
const forgeApplicationId = 'tom-forge';

/// The Dart editor's summaries in an app built on this library: the two files
/// `tom_forge_app` carries, under its package prefix.
final ForgeDartSummaryAssets forgeSuiteDartSummaries =
    ForgeDartSummaryAssets.ofPackage('tom_forge_app');

/// Composes Tom Forge on [shell] for [workspaceRoot]: the shell module, the
/// app module and the website editor module, the tom_forge application, then
/// each extension's modules and applications. Applications open at the last
/// exit come back through their factories ([ForgeShellApi.restoreApplications])
/// once everything is registered.
///
/// [dartSummaryAssets] is where the Dart editor reads its summaries: Tom
/// Forge's own app carries them ([ForgeDartSummaryAssets.root]), an app built
/// on this library reads this package's ([forgeSuiteDartSummaries]).
Future<ForgeSuite> composeForgeSuite({
  required DefaultShellApi shell,
  required String workspaceRoot,
  GlobalKey<NavigatorState>? navigatorKey,
  List<ForgeSuiteExtension> extensions = const [],
  ForgeDartSummaryAssets dartSummaryAssets = ForgeDartSummaryAssets.root,
  bool restoreApplications = true,
}) async {
  // The root is set before the modules activate: the website module
  // resolves its config file against it.
  (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);
  (shell.layout as DefaultLayoutController).dartSummaryAssets =
      dartSummaryAssets;
  final suite = ForgeSuite._(
    shell: shell,
    navigatorKey: navigatorKey,
    workspaceRoot: workspaceRoot,
    shellModule: TomForgeShellModule(),
    appModule: ForgeAppModule(workspaceRootUri: Directory(workspaceRoot).uri),
    websiteModule: WebsiteEditorModule(),
  );
  suite
    .._register(suite.shellModule)
    .._register(suite.appModule)
    // The website editor (§9): the site preview, the dev-server / generator
    // panel and the content catalog. It disables itself when the workspace
    // has no tom.website-editor.yaml.
    .._register(suite.websiteModule);

  suite.forgeApplication = _forgeApplication(suite);
  shell.applications.add(suite.forgeApplication);

  for (final extension in extensions) {
    for (final module in extension.modules?.call(suite) ?? const <ForgeModule>[]) {
      suite._register(module);
      suite.extensionModules.add(module);
    }
  }
  for (final extension in extensions) {
    for (final app in extension.applications?.call(suite) ??
        const <ForgeApplication>[]) {
      shell.applications.add(app);
      suite.extensionApplications.add(app);
    }
  }
  if (restoreApplications) await shell.restoreApplications();
  return suite;
}

ForgeApplication _forgeApplication(ForgeSuite suite) {
  ForgeView view(String title) =>
      suite.appModule.views.firstWhere((v) => v.title.value == title);
  final website = suite.websiteModule;
  return ForgeApplication(
    id: forgeApplicationId,
    title: 'Tom Forge',
    workspaceFolder: suite.workspaceRoot.split(Platform.pathSeparator).last,
    layout: PanelLayout(
      leftPanel: PanelConfig(
        initialSize: 250,
        tabs: [
          PanelTabConfig(
            title: 'Explorer',
            icon: Icons.folder_outlined,
            sections: [view('Explorer'), view('Revisions')],
          ),
          PanelTabConfig(
            title: 'Search',
            icon: Icons.search,
            sections: [view('Search')],
          ),
          PanelTabConfig(
            title: 'Website',
            icon: Icons.public,
            sections: [
              website.controlView!,
              website.contentView!,
              website.structureView!,
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
            sections: [view('Outline')],
          ),
        ],
      ),
      bottomPanel: PanelConfig(
        initialSize: 180,
        tabs: [
          PanelTabConfig(
            title: 'Problems',
            icon: Icons.error_outline,
            sections: [view('Problems')],
          ),
          PanelTabConfig(
            title: 'Output',
            icon: Icons.terminal,
            sections: [view('Output')],
          ),
          PanelTabConfig(
            title: 'Web Preview',
            icon: Icons.web,
            sections: [website.previewView!],
          ),
          const PanelTabConfig(title: 'Terminal', icon: Icons.code, sections: []),
        ],
      ),
      middlePanels: [const MiddlePanelConfig()],
    ),
  );
}

/// The folder a picked folder resolves to and its workspace state: a
/// workspace root detected above the folder is taken only when it can be
/// read (the macOS sandbox grants the picked folder alone), the workspace
/// state initialised, a `.gitignore` entry suggested, and the folder
/// remembered as the last workspace.
Future<(String, DefaultWorkspaceStateManager)> resolveForgeWorkspace(
  Directory picked,
) async {
  final state = DefaultWorkspaceStateManager();
  String? detected;
  try {
    detected = await state.detectWorkspaceRoot(picked.path);
    if (detected != null && detected != picked.path) {
      try {
        await Directory(detected).list(followLinks: false).first;
      } on StateError {
        // Empty but readable — accepted.
      } catch (e) {
        debugPrint('[forge_suite] cannot access detected root $detected: $e');
        detected = null;
      }
    }
  } catch (e) {
    debugPrint('[forge_suite] detectWorkspaceRoot failed: $e');
    detected = null;
  }
  final root = detected ?? picked.path;
  try {
    await state.initialize(root);
  } catch (e) {
    debugPrint('[forge_suite] workspace initialize failed: $e');
  }
  try {
    await state.suggestGitignore(root);
  } catch (e) {
    debugPrint('[forge_suite] suggestGitignore failed: $e');
  }
  final prefs = ForgePreferencesService.instance;
  if (!prefs.isLoaded) await prefs.load();
  prefs.startupPreferences.lastWorkspacePath = root;
  await prefs.save();
  return (root, state);
}

/// The root widget of an app built on Tom Forge: the welcome page until a
/// folder is picked, then the shell over that folder with Tom Forge composed
/// on it and [extensions] added. Tom Forge's own app is this with no
/// extensions; Webforge adds the Webwork full-screen application and the
/// quest extension.
class ForgeSuiteLauncher extends StatefulWidget {
  const ForgeSuiteLauncher({
    super.key,
    this.appName = 'Tom Forge',
    this.extensions = const [],
    this.workspace,
    this.dartSummaryAssets = ForgeDartSummaryAssets.root,
    this.onComposed,
  });

  /// The app's name: the window title and the shell's.
  final String appName;

  final List<ForgeSuiteExtension> extensions;

  /// A folder to open at once instead of showing the welcome page — the
  /// command line's; null shows the welcome page.
  final Directory? workspace;

  /// Where the Dart editor reads its summaries ([composeForgeSuite]).
  final ForgeDartSummaryAssets dartSummaryAssets;

  /// Called once a folder's suite is composed and about to be shown, for a
  /// host that opens files in it (the command line's documents).
  final void Function(ForgeSuite suite)? onComposed;

  @override
  State<ForgeSuiteLauncher> createState() => _ForgeSuiteLauncherState();
}

class _ForgeSuiteLauncherState extends State<ForgeSuiteLauncher> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final DefaultShellApi _placeholder = DefaultShellApi.withDefaults(
    fileSystemSeed: const {},
    appName: widget.appName,
    navigatorKey: _navigatorKey,
  );
  DefaultShellApi? _shell;

  @override
  void initState() {
    super.initState();
    final workspace = widget.workspace;
    if (workspace != null) _open(workspace);
  }

  void _open(Directory folder) => unawaited(_openAsync(folder));

  Future<void> _openAsync(Directory folder) async {
    final (root, state) = await resolveForgeWorkspace(folder);
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: TomLocalFileSystem(root),
      appName: widget.appName,
      navigatorKey: _navigatorKey,
      workspaceState: state,
      storage: PersistentModuleStorage(forgeDir: state.forgeDirectoryPath),
    );
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: root,
      navigatorKey: _navigatorKey,
      extensions: widget.extensions,
      dartSummaryAssets: widget.dartSummaryAssets,
    );
    if (!mounted) {
      shell.dispose();
      return;
    }
    final previous = _shell;
    setState(() => _shell = shell);
    widget.onComposed?.call(suite);
    // The previous folder's shell goes once its scaffold has left the tree.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _shell?.dispose();
    _placeholder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ForgeApp(
    title: widget.appName,
    shell: _shell ?? _placeholder,
    navigatorKey: _navigatorKey,
    onWorkspaceSelected: _open,
    workspaceReady: _shell != null,
  );
}
