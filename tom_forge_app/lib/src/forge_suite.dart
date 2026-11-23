import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_file_system/io.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_office_editors/tom_forge_office_editors.dart';
import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart';
import 'package:tom_forge_quests/tom_forge_quests.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        DefaultLayoutController,
        DefaultModuleRegistry,
        DefaultShellApi,
        DefaultSystemState,
        ForgeApplication,
        ForgeModule,
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
import 'package:tom_website_editor/tom_website_editor.dart';
import 'package:tom_highlight_js/tom_highlight_js.dart'
    show registerHighlightJsLanguages;

import 'app.dart';
import 'forge_app_module.dart';

/// What a host adds to Tom Forge: modules activated and registered after
/// Forge's own, and applications added after the tom_forge application.
///
/// Both are made from the composed [ForgeSuite], so an extension's
/// application can lay out views of Forge's modules as well as its own.
class ForgeSuiteExtension {
  const ForgeSuiteExtension({
    this.modules,
    this.applications,
    this.fileEditorBuilders,
    this.fileEditorAlternatives,
  });

  /// The extension's modules; the suite activates and registers each.
  final List<ForgeModule> Function(ForgeSuite suite)? modules;

  /// Editors the extension puts in place of Forge's for a kind of file
  /// (Webwork's rich Markdown editor, say), by the kind's id
  /// ([ForgeKitFileKind.id] of a kind in [forgeSuiteFileKinds], or
  /// [ForgeFileKind.name] of the file editors' own), made once its modules
  /// are registered; a later extension's builder of a kind wins.
  final Map<String, ForgeFileEditorBuilder> Function(ForgeSuite suite)?
  fileEditorBuilders;

  /// Other editors the extension offers for some files beside Forge's editor
  /// of their kind — Open With lists both (Webforge's TomSpecs editor for a
  /// spec document beside the YAML editor).
  final List<ForgeFileEditorAlternative> Function(ForgeSuite suite)?
  fileEditorAlternatives;

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
    required this.questsModule,
    required this.officeModule,
    required this.pdfModule,
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

  /// The quest applications: their factory and the Open Quest picker, in the
  /// tom_forge application and every quest application.
  final ForgeQuestsModule questsModule;

  /// The office editors: LibreOfficeKit (the default for the office kinds)
  /// and ZetaOffice, under *Open With*; LibreOffice's External Tools row.
  /// Asked before the PDF editors, the extensions' modules and the file
  /// editors.
  final ForgeOfficeEditorsModule officeModule;

  /// The PDF editors: PDFium (the default for `.pdf`) and pdf.js, under
  /// *Open With*. Asked before the extensions' modules and the file editors.
  final ForgePdfEditorsModule pdfModule;

  /// The tom_forge application (Forge's own panel layout).
  late final ForgeApplication forgeApplication;

  /// The file editors: every file a module does not take opens in the editor
  /// of its kind over a `ForgeFileSession` (see [composeForgeSuite]).
  late final ForgeFileEditorsModule fileEditorsModule;

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

/// What Tom Forge hands its shells on the desktop: the terminal, the code
/// editors, the platform keychain and the desktop host (file dialogs, shells,
/// folders), composed from the shell parts.
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

/// The file kinds Tom Forge hands its file editors module, beside the
/// module's own `.env`, todo-file and plain-text kinds: the Markdown and YAML
/// adapters' ([forgeMarkdownFileKind], [forgeYamlFileKind]), asked in this
/// order.
final List<ForgeKitFileKind> forgeSuiteFileKinds = List.unmodifiable([
  forgeMarkdownFileKind,
  forgeYamlFileKind,
]);

/// The Dart editor's summaries in an app built on this library: the two files
/// `tom_forge_app` carries, under its package prefix.
final ForgeDartSummaryAssets forgeSuiteDartSummaries =
    ForgeDartSummaryAssets.ofPackage('tom_forge_app');

/// Highlights code blocks in every highlight.js language (`tom_highlight_js`)
/// beyond the ones `tom_text_highlight` has of its own, as Tom Forge always
/// has: the Markdown editor's preview and code-block overlay and the file
/// editors' Markdown renderer ask `highlighterForLanguage`. Tom Forge's
/// `main` calls it once; an application composed differently decides itself.
void useForgeCodeHighlighting() => registerHighlightJsLanguages();

/// Composes Tom Forge on [shell] for [workspaceRoot]: the shell module, the
/// app module, the website editor module, the quests module, the office
/// editors module and the PDF editors module, the
/// tom_forge application, each extension's modules, the file editors module
/// (with the file kinds of [forgeSuiteFileKinds] and the extensions'
/// [ForgeSuiteExtension.fileEditorBuilders]), then each
/// extension's applications. Applications open at the last
/// exit come back through their factories ([ForgeShellApi.restoreApplications])
/// once everything is registered.
///
/// [dartSummaryAssets] is where the Dart editor reads its summaries: Tom
/// Forge's own app carries them ([ForgeDartSummaryAssets.root]), an app built
/// on this library reads this package's ([forgeSuiteDartSummaries]).
///
/// [officeModule] is the office editors module; by default the desktop's,
/// which detects LibreOffice at activation with short processes. A widget
/// test gives one whose `detect` starts no process: their timeouts would
/// stay pending on the test's clock.
Future<ForgeSuite> composeForgeSuite({
  required DefaultShellApi shell,
  required String workspaceRoot,
  GlobalKey<NavigatorState>? navigatorKey,
  List<ForgeSuiteExtension> extensions = const [],
  ForgeDartSummaryAssets dartSummaryAssets = ForgeDartSummaryAssets.root,
  bool restoreApplications = true,
  ForgeOfficeEditorsModule? officeModule,
}) async {
  // The root is set before the modules activate: the website module
  // resolves its config file against it.
  (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);
  ForgeDartSummariesByHost.set(shell.layout, dartSummaryAssets);
  final suite = ForgeSuite._(
    shell: shell,
    navigatorKey: navigatorKey,
    workspaceRoot: workspaceRoot,
    shellModule: TomForgeShellModule(),
    appModule: ForgeAppModule(workspaceRootUri: Directory(workspaceRoot).uri),
    websiteModule: WebsiteEditorModule(),
    questsModule: ForgeQuestsModule(),
    officeModule: officeModule ?? ForgeOfficeEditorsModule(),
    pdfModule: ForgePdfEditorsModule(),
  );
  suite
    .._register(suite.shellModule)
    .._register(suite.appModule)
    // The website editor (§9): the site preview, the dev-server / generator
    // panel and the content catalog. It disables itself when the workspace
    // has no tom.website-editor.yaml.
    .._register(suite.websiteModule)
    // The quest applications (one per open quest): registered before the
    // restore below, which recreates the ones open at the last exit.
    .._register(suite.questsModule)
    // The office editors, Forge's own: after the quests module, before the
    // PDF editors and the extensions' modules (an extension's office editor
    // adds a choice, it does not replace the default) and so before the
    // file editors.
    .._register(suite.officeModule)
    // The PDF editors, Forge's own: after the quests module, before the
    // extensions' modules (an extension's PDF editor adds a choice, it does
    // not replace the default) and so before the file editors.
    .._register(suite.pdfModule);

  suite.forgeApplication = _forgeApplication(suite);
  shell.applications.add(suite.forgeApplication);

  for (final extension in extensions) {
    for (final module
        in extension.modules?.call(suite) ?? const <ForgeModule>[]) {
      suite._register(module);
      suite.extensionModules.add(module);
    }
  }
  // After the extensions' modules, so a module that opens its own files (a
  // Webwork document) is asked first.
  suite.fileEditorsModule = ForgeFileEditorsModule(
    fileKinds: ForgeFileKindRegistry(forgeSuiteFileKinds),
    builders: {
      for (final extension in extensions)
        ...?extension.fileEditorBuilders?.call(suite),
    },
    alternatives: [
      for (final extension in extensions)
        ...?extension.fileEditorAlternatives?.call(suite),
    ],
    claims: (uri) => _fileEditorsClaim(shell, uri),
  );
  suite._register(suite.fileEditorsModule);
  for (final extension in extensions) {
    for (final app
        in extension.applications?.call(suite) ?? const <ForgeApplication>[]) {
      shell.applications.add(app);
      suite.extensionApplications.add(app);
    }
  }
  if (restoreApplications) await shell.restoreApplications();
  return suite;
}

/// Whether the file editors open [uri]: not a file another module's editor
/// takes (the website module's `tom.website-editor.yaml`), not an office
/// file or a PDF (the office and PDF editors modules', even before they have
/// an editor open; `.csv` stays the file editors'), not a Dart file
/// (the shell's Dart editor), and not a file whose extension the user gave a
/// default editor of the shell's.
bool _fileEditorsClaim(DefaultShellApi shell, Uri uri) {
  for (final module in shell.modules.allModules) {
    if (module is ForgeOfficeEditorsModule && module.handles(uri)) {
      return false;
    }
    if (module is ForgePdfEditorsModule && module.handles(uri)) return false;
    // The shell module lists the shell's own open editors, and the file
    // editors module its own: neither takes a file away.
    if (module is TomForgeShellModule || module is ForgeFileEditorsModule) {
      continue;
    }
    for (final editor in module.editors) {
      if (editor.canHandle(uri) == FileHandlingResult.accept) return false;
    }
  }
  final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (extension == 'dart') return false;
  final layout = shell.layout as DefaultLayoutController;
  return layout.getFileTypeDefaultEditor(extension) == null;
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
          const PanelTabConfig(
            title: 'Terminal',
            icon: Icons.code,
            sections: [],
          ),
        ],
      ),
      middlePanels: [const MiddlePanelConfig()],
    ),
  );
}

/// The folder a picked folder resolves to and its workspace state: a
/// workspace root detected above the folder is taken only when it can be
/// read (the macOS sandbox grants the picked folder alone), the workspace
/// state initialised over the workspace's file system (which the shell then
/// shares), `.forge/` kept out of git, and the folder remembered as the last
/// workspace.
Future<(String, DefaultWorkspaceStateManager)> resolveForgeWorkspace(
  Directory picked,
) async {
  final state = DefaultWorkspaceStateManager();
  String? detected;
  try {
    detected = await detectForgeWorkspaceRoot(picked.path);
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
    // The one file system of the workspace: the shell's, and the state's.
    await state.initialize(TomLocalFileSystem(root));
  } catch (e) {
    debugPrint('[forge_suite] workspace initialize failed: $e');
  }
  try {
    // `.forge/` is per-machine state: kept out of git through the clone's
    // own exclude file, never by editing a file the workspace tracks.
    await keepForgeStateOutOfGit(root);
  } catch (e) {
    debugPrint('[forge_suite] keepForgeStateOutOfGit failed: $e');
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
    components: _desktopComponents,
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
    final fileSystem = state.isInitialized
        ? state.fileSystem
        : TomLocalFileSystem(root);
    final shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fileSystem,
      appName: widget.appName,
      navigatorKey: _navigatorKey,
      workspaceState: state,
      storage: await PersistentModuleStorage.open(fileSystem),
      // The terminal, the code editors and the keychain.
      components: _desktopComponents,
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
