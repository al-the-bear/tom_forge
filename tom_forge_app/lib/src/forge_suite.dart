import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_file_system/io.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show FileHandlingResult, ForgePanelLocation;
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_office_lok/tom_forge_office_lok.dart';
import 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart';
import 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart';
import 'package:tom_forge_pdf_pdfjs/tom_forge_pdf_pdfjs.dart';
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
        forgeContributedPanelTabs,
        forgeContributedTerminalTab,
        PanelConfig,
        PanelLayout,
        PanelTabConfig,
        TomForgeShellModule;
import 'package:tom_forge_file_explorer/tom_forge_file_explorer.dart';
import 'package:tom_forge_outline_view/tom_forge_outline_view.dart';
import 'package:tom_forge_output_view/tom_forge_output_view.dart';
import 'package:tom_forge_command_palette/tom_forge_command_palette.dart';
import 'package:tom_forge_problems_view/tom_forge_problems_view.dart';
import 'package:tom_forge_quick_open/tom_forge_quick_open.dart';
import 'package:tom_forge_revision_view/tom_forge_revision_view.dart';
import 'package:tom_forge_search_view/tom_forge_search_view.dart';
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

/// The modules [composeForgeSuite] can register beside the ones every suite
/// has (the shell module, the app module and the file editors module, the
/// host of the file kinds): one entry per module or file kind, in the order
/// the suite registers them. A module not asked for is not constructed.
///
/// The order of a given set does not matter: the suite registers what it is
/// given in this order (the views' panel order, the office and PDF editors'
/// Open With order follow it).
enum ForgeSuiteModule {
  /// The file explorer (`tom_forge_file_explorer`) over the workspace folder.
  fileExplorer,

  /// The Problems view (`tom_forge_problems_view`).
  problemsView,

  /// The Search view (`tom_forge_search_view`) over the workspace folder.
  searchView,

  /// The Outline view (`tom_forge_outline_view`).
  outlineView,

  /// The Output view (`tom_forge_output_view`).
  outputView,

  /// The Revisions view (`tom_forge_revision_view`).
  revisionView,

  /// Quick open (`tom_forge_quick_open`).
  quickOpen,

  /// The command palette (`tom_forge_command_palette`).
  commandPalette,

  /// The terminals' placement: the bottom panel's Terminal tab
  /// (`tom_forge_terminal`).
  terminal,

  /// The website editor (`tom_website_editor`) and the tom_forge
  /// application's Website and Web Preview tabs.
  websiteEditor,

  /// The quest applications and the Open Quest picker (`tom_forge_quests`).
  quests,

  /// The LibreOfficeKit office editor (`tom_forge_office_lok`); with
  /// [officeZetaOffice] too, ZetaOffice is its alternative route.
  officeLok,

  /// The ZetaOffice office editor (`tom_forge_office_zetaoffice`).
  officeZetaOffice,

  /// The PDFium PDF editor (`tom_forge_pdf_pdfium`).
  pdfium,

  /// The pdf.js PDF view (`tom_forge_pdf_pdfjs`).
  pdfJs,

  /// The Markdown file kind ([forgeMarkdownFileKind]) in the file editors.
  markdownFileKind,

  /// The YAML file kind ([forgeYamlFileKind]) in the file editors.
  yamlFileKind;

  /// Every module: Tom Forge as `tom_forge_app` builds it.
  static const Set<ForgeSuiteModule> all = {
    fileExplorer,
    problemsView,
    searchView,
    outlineView,
    outputView,
    revisionView,
    quickOpen,
    commandPalette,
    terminal,
    websiteEditor,
    quests,
    officeLok,
    officeZetaOffice,
    pdfium,
    pdfJs,
    markdownFileKind,
    yamlFileKind,
  };
}

/// Tom Forge composed on a shell: its modules, its application, and what the
/// extensions added.
///
/// The modules the suite was asked for ([modules]) are its own; a getter of
/// one it was not asked for throws a [StateError] ([has] tells first).
class ForgeSuite {
  ForgeSuite._({
    required this.shell,
    required this.navigatorKey,
    required this.workspaceRoot,
    required this.modules,
    required this.shellModule,
    required this.appModule,
  });

  final DefaultShellApi shell;

  /// The navigator the shell's dialogs are routed through, for an extension
  /// module that raises its own; null when the composer was given none.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The workspace folder the suite edits.
  final String workspaceRoot;

  /// The modules the suite registered beside the ones every suite has.
  final Set<ForgeSuiteModule> modules;

  /// Whether the suite registered [module].
  bool has(ForgeSuiteModule module) => modules.contains(module);

  final TomForgeShellModule shellModule;
  final ForgeAppModule appModule;

  T _module<T extends Object>(T? module, ForgeSuiteModule id) =>
      module ??
      (throw StateError(
        'The suite was composed without ${id.name} '
        '(composeForgeSuite modules: ${modules.map((m) => m.name)})',
      ));

  ForgeFileExplorerModule? _fileExplorerModule;
  ForgeProblemsViewModule? _problemsViewModule;
  ForgeSearchViewModule? _searchViewModule;
  ForgeOutlineViewModule? _outlineViewModule;
  ForgeOutputViewModule? _outputViewModule;
  ForgeRevisionViewModule? _revisionViewModule;
  ForgeQuickOpenModule? _quickOpenModule;
  ForgeCommandPaletteModule? _commandPaletteModule;
  ForgeTerminalModule? _terminalModule;
  WebsiteEditorModule? _websiteModule;
  ForgeQuestsModule? _questsModule;
  ForgeOfficeLokModule? _officeLokModule;
  ForgeZetaOfficeModule? _officeZetaOfficeModule;
  ForgePdfiumModule? _pdfiumModule;
  ForgePdfJsModule? _pdfJsModule;

  /// The views, packages of their own, each a kit module placed by its hint:
  /// the file explorer and the Search view over the app module's workspace
  /// folder, Problems, Outline, Output, Revisions (registered after the app
  /// module, in this order).
  ForgeFileExplorerModule get fileExplorerModule =>
      _module(_fileExplorerModule, ForgeSuiteModule.fileExplorer);
  ForgeProblemsViewModule get problemsViewModule =>
      _module(_problemsViewModule, ForgeSuiteModule.problemsView);
  ForgeSearchViewModule get searchViewModule =>
      _module(_searchViewModule, ForgeSuiteModule.searchView);
  ForgeOutlineViewModule get outlineViewModule =>
      _module(_outlineViewModule, ForgeSuiteModule.outlineView);
  ForgeOutputViewModule get outputViewModule =>
      _module(_outputViewModule, ForgeSuiteModule.outputView);
  ForgeRevisionViewModule get revisionViewModule =>
      _module(_revisionViewModule, ForgeSuiteModule.revisionView);

  /// Quick open and the command palette, packages of their own: the overlay
  /// the shell shows when the user opens them (quick open wins; the palette
  /// is what a shell without quick open shows).
  ForgeQuickOpenModule get quickOpenModule =>
      _module(_quickOpenModule, ForgeSuiteModule.quickOpen);
  ForgeCommandPaletteModule get commandPaletteModule =>
      _module(_commandPaletteModule, ForgeSuiteModule.commandPalette);

  /// Where the terminals go: the bottom panel's Terminal tab.
  ForgeTerminalModule get terminalModule =>
      _module(_terminalModule, ForgeSuiteModule.terminal);

  /// The website editor: the site preview, the dev-server / generator panel
  /// and the content catalog.
  WebsiteEditorModule get websiteModule =>
      _module(_websiteModule, ForgeSuiteModule.websiteEditor);

  /// The quest applications: their factory and the Open Quest picker, in the
  /// tom_forge application and every quest application.
  ForgeQuestsModule get questsModule =>
      _module(_questsModule, ForgeSuiteModule.quests);

  /// The LibreOfficeKit office editor (`tom_forge_office_lok`): the default
  /// for the office kinds, under *Open With*, and LibreOffice's External
  /// Tools row; ZetaOffice ([officeZetaOfficeModule]) is its alternative
  /// route when the suite has it. Asked before ZetaOffice, the PDF editors,
  /// the extensions' modules and the file editors.
  ForgeOfficeLokModule get officeLokModule =>
      _module(_officeLokModule, ForgeSuiteModule.officeLok);

  /// The ZetaOffice office editor (`tom_forge_office_zetaoffice`): offered
  /// under *Open With* for the office kinds, and the route the
  /// missing-LibreOffice panel offers.
  ForgeZetaOfficeModule get officeZetaOfficeModule =>
      _module(_officeZetaOfficeModule, ForgeSuiteModule.officeZetaOffice);

  /// The PDFium editor (`tom_forge_pdf_pdfium`): the default for `.pdf`,
  /// under *Open With*. Asked before pdf.js, the extensions' modules and the
  /// file editors.
  ForgePdfiumModule get pdfiumModule =>
      _module(_pdfiumModule, ForgeSuiteModule.pdfium);

  /// The pdf.js view (`tom_forge_pdf_pdfjs`), offered under *Open With* for
  /// `.pdf`.
  ForgePdfJsModule get pdfJsModule =>
      _module(_pdfJsModule, ForgeSuiteModule.pdfJs);

  /// The tom_forge application (Forge's own panel layout).
  late final ForgeApplication forgeApplication;

  /// The file editors: every file a module does not take opens in the editor
  /// of its kind over a `ForgeFileSession` (see [composeForgeSuite]).
  late final ForgeFileEditorsModule fileEditorsModule;

  /// The modules the extensions added, in order.
  final List<ForgeModule> extensionModules = [];

  /// The applications the extensions added, in order.
  final List<ForgeApplication> extensionApplications = [];

  void _register(ForgeModule? module) {
    if (module == null) return;
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
  }

  /// Registers a module written against the kit alone (activated with the
  /// shell's API).
  void _registerKitModule(ForgeKitModule? module) {
    if (module != null) shell.registerModule(module);
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
/// order (each when the suite has it: [ForgeSuiteModule.markdownFileKind],
/// [ForgeSuiteModule.yamlFileKind]).
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
/// app module, the views, quick open, the command palette, the terminals'
/// placement, the website editor module, the quests module, the office
/// editors (LibreOfficeKit, then ZetaOffice) and the PDF editors (PDFium,
/// then pdf.js) — of these the ones [modules] names —, the tom_forge
/// application, each extension's modules, the file editors module (with the
/// file kinds of [forgeSuiteFileKinds] the suite has and the extensions'
/// [ForgeSuiteExtension.fileEditorBuilders]), then each extension's
/// applications. Applications open at the last
/// exit come back through their factories ([ForgeShellApi.restoreApplications])
/// once everything is registered.
///
/// [dartSummaryAssets] is where the Dart editor reads its summaries: Tom
/// Forge's own app carries them ([ForgeDartSummaryAssets.root]), an app built
/// on this library reads this package's ([forgeSuiteDartSummaries]).
///
/// [modules] are the modules registered beside the shell module, the app
/// module and the file editors module, which every suite has: by default
/// all of them ([ForgeSuiteModule.all], Tom Forge as `tom_forge_app` builds
/// it); a lighter build names fewer. A module left out is not constructed,
/// its getter on the suite throws, and nothing else asks for it: Open With
/// lists the editors of the modules there are, the tom_forge application
/// leaves out the Website and Web Preview tabs without the website editor,
/// and the LibreOfficeKit module has no alternative route without ZetaOffice.
/// The file editors take the file kinds named ([ForgeSuiteModule.markdownFileKind],
/// [ForgeSuiteModule.yamlFileKind]) beside their own `.env`, todo-file and
/// plain-text kinds.
///
/// [officeLokModule] is the LibreOfficeKit office module; by default the
/// desktop's, which detects LibreOffice at activation with short processes
/// and offers [officeZetaOfficeModule] (by default the desktop's) as its
/// alternative route. A widget test gives one whose `detect` starts no
/// process: their timeouts would stay pending on the test's clock. A given
/// module is used as it is: it has the alternative route it was made with.
/// Either is used only when [modules] names it.
Future<ForgeSuite> composeForgeSuite({
  required DefaultShellApi shell,
  required String workspaceRoot,
  GlobalKey<NavigatorState>? navigatorKey,
  Set<ForgeSuiteModule> modules = ForgeSuiteModule.all,
  List<ForgeSuiteExtension> extensions = const [],
  ForgeDartSummaryAssets dartSummaryAssets = ForgeDartSummaryAssets.root,
  bool restoreApplications = true,
  ForgeOfficeLokModule? officeLokModule,
  ForgeZetaOfficeModule? officeZetaOfficeModule,
}) async {
  final selected = Set<ForgeSuiteModule>.unmodifiable(modules);
  bool has(ForgeSuiteModule module) => selected.contains(module);
  // The root is set before the modules activate: the website module
  // resolves its config file against it.
  (shell.systemState as DefaultSystemState).setWorkspaceRootPath(workspaceRoot);
  ForgeDartSummariesByHost.set(shell.layout, dartSummaryAssets);
  final openExternal = shell.environment.openExternal;
  final windowFocus = shell.systemState.onWindowFocusChanged.map(
    (e) => e.focused,
  );
  final focusRegained = windowFocus.where((focused) => focused);
  final zeta = !has(ForgeSuiteModule.officeZetaOffice)
      ? null
      : officeZetaOfficeModule ??
            ForgeZetaOfficeModule(
              openExternal: openExternal,
              windowFocus: windowFocus,
            );
  final lok = !has(ForgeSuiteModule.officeLok)
      ? null
      : officeLokModule ??
            ForgeOfficeLokModule(
              preferences: ForgePreferencesService.instance,
              openExternal: openExternal,
              filePickers: () => ForgeShellComponents.of(shell).pickers,
              windowFocus: windowFocus,
              alternative: zeta == null
                  ? null
                  : ForgeOfficeAlternativeRoute(
                      choiceId: ForgeZetaOfficeModule.choiceId,
                      label: ForgeZetaOfficeModule.openLabel,
                      open: zeta.open,
                      editors: () => zeta.editors,
                      available: zeta.available,
                      check: zeta.checkAvailable,
                    ),
            );
  final appModule = ForgeAppModule(
    workspaceRootUri: Directory(workspaceRoot).uri,
  );
  final suite = ForgeSuite._(
    shell: shell,
    navigatorKey: navigatorKey,
    workspaceRoot: workspaceRoot,
    modules: selected,
    shellModule: TomForgeShellModule(),
    appModule: appModule,
  );
  suite
    // The views, packages of their own (CMP-2): placed by their hints.
    .._fileExplorerModule = has(ForgeSuiteModule.fileExplorer)
        ? forgeFileExplorerModule(rootUri: appModule.workspaceRootUri)
        : null
    .._problemsViewModule = has(ForgeSuiteModule.problemsView)
        ? forgeProblemsViewModule()
        : null
    .._searchViewModule = has(ForgeSuiteModule.searchView)
        ? forgeSearchViewModule(
            workspaceRoot: appModule.workspaceRootUri.toFilePath(),
          )
        : null
    .._outlineViewModule = has(ForgeSuiteModule.outlineView)
        ? forgeOutlineViewModule()
        : null
    .._outputViewModule = has(ForgeSuiteModule.outputView)
        ? forgeOutputViewModule()
        : null
    .._revisionViewModule = has(ForgeSuiteModule.revisionView)
        ? forgeRevisionViewModule()
        : null
    .._quickOpenModule = has(ForgeSuiteModule.quickOpen)
        ? forgeQuickOpenModule()
        : null
    .._commandPaletteModule = has(ForgeSuiteModule.commandPalette)
        ? forgeCommandPaletteModule()
        : null
    .._terminalModule = has(ForgeSuiteModule.terminal)
        ? forgeTerminalModule()
        : null
    .._websiteModule = has(ForgeSuiteModule.websiteEditor)
        ? WebsiteEditorModule()
        : null
    .._questsModule = has(ForgeSuiteModule.quests) ? ForgeQuestsModule() : null
    .._officeLokModule = lok
    .._officeZetaOfficeModule = zeta
    .._pdfiumModule = has(ForgeSuiteModule.pdfium)
        ? ForgePdfiumModule(
            openExternal: openExternal,
            windowFocusRegained: focusRegained,
          )
        : null
    .._pdfJsModule = has(ForgeSuiteModule.pdfJs)
        ? ForgePdfJsModule(
            openExternal: openExternal,
            windowFocusRegained: focusRegained,
          )
        : null;
  suite
    .._register(suite.shellModule)
    .._register(suite.appModule)
    // The views, packages of their own (CMP-2): placed by their hints.
    .._registerKitModule(suite._fileExplorerModule)
    .._registerKitModule(suite._problemsViewModule)
    .._registerKitModule(suite._searchViewModule)
    .._registerKitModule(suite._outlineViewModule)
    .._registerKitModule(suite._outputViewModule)
    .._registerKitModule(suite._revisionViewModule)
    // Quick open, the command palette and the terminals' placement.
    .._registerKitModule(suite._quickOpenModule)
    .._registerKitModule(suite._commandPaletteModule)
    .._registerKitModule(suite._terminalModule)
    // The website editor (§9): the site preview, the dev-server / generator
    // panel and the content catalog. It disables itself when the workspace
    // has no tom.website-editor.yaml.
    .._register(suite._websiteModule)
    // The quest applications (one per open quest): registered before the
    // restore below, which recreates the ones open at the last exit.
    .._register(suite._questsModule)
    // The office editors, Forge's own, kit modules (one per route):
    // LibreOfficeKit first (the default; it leaves a file to ZetaOffice
    // when the file-type default names it), then ZetaOffice; after the
    // quests module, before the PDF editors and the extensions' modules (an
    // extension's office editor adds a choice, it does not replace the
    // default) and so before the file editors.
    .._registerKitModule(suite._officeLokModule)
    .._registerKitModule(suite._officeZetaOfficeModule)
    // The PDF editors, Forge's own, kit modules (one per engine): PDFium
    // first (the default), then pdf.js; before the extensions' modules (an
    // extension's PDF editor adds a choice, it does not replace the default)
    // and so before the file editors.
    .._registerKitModule(suite._pdfiumModule)
    .._registerKitModule(suite._pdfJsModule);

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
    fileKinds: ForgeFileKindRegistry([
      if (has(ForgeSuiteModule.markdownFileKind)) forgeMarkdownFileKind,
      if (has(ForgeSuiteModule.yamlFileKind)) forgeYamlFileKind,
    ]),
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
  // Every module, the kit modules (the office and PDF editors, the views)
  // with the shell's own.
  for (final module in shell.modules.allKitModules) {
    if (module is ForgeOfficeLokModule && module.handles(uri)) return false;
    if (module is ForgeZetaOfficeModule && module.handles(uri)) return false;
    if (module is ForgePdfiumModule && module.handles(uri)) return false;
    if (module is ForgePdfJsModule && module.handles(uri)) return false;
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

/// The tom_forge application: its side and bottom panels laid out from the
/// views the registered modules contribute, by their placement hints
/// ([forgeContributedPanelTabs]: Explorer with Revisions and Search on the
/// left, Outline on the right, Problems and Output at the bottom), with the
/// website editor's tabs (when the suite has it) and the terminal tab its
/// terminal module places
/// ([forgeContributedTerminalTab]) added.
ForgeApplication _forgeApplication(ForgeSuite suite) {
  final modules = suite.shell.modules;
  final website = suite._websiteModule;
  return ForgeApplication(
    id: forgeApplicationId,
    title: 'Tom Forge',
    workspaceFolder: suite.workspaceRoot.split(Platform.pathSeparator).last,
    layout: PanelLayout(
      leftPanel: PanelConfig(
        initialSize: 250,
        tabs: [
          ...forgeContributedPanelTabs(modules, ForgePanelLocation.left),
          if (website != null)
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
        tabs: forgeContributedPanelTabs(modules, ForgePanelLocation.right),
      ),
      bottomPanel: PanelConfig(
        initialSize: 180,
        tabs: [
          ...forgeContributedPanelTabs(modules, ForgePanelLocation.bottom),
          if (website != null)
            PanelTabConfig(
              title: 'Web Preview',
              icon: Icons.web,
              sections: [website.previewView!],
            ),
          ?forgeContributedTerminalTab(modules),
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
    this.modules = ForgeSuiteModule.all,
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

  /// The modules the suite registers ([composeForgeSuite]); all by default.
  final Set<ForgeSuiteModule> modules;

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
      modules: widget.modules,
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
