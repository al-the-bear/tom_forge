/// The suite's module list (forgerestruct16, CMP-4): `composeForgeSuite`
/// registers the modules it is given beside the shell, app and file editors
/// modules every suite has — by default all of them, as `tom_forge_app`
/// builds Tom Forge. A module left out is not constructed, its getter throws,
/// Open With lists only the editors of the modules there are, and the
/// tom_forge application leaves out the tabs of the modules it lacks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_app/forge_suite.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_file_explorer/tom_forge_file_explorer.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultShellApi, ForgeModule, PanelLayout;
import 'package:tom_website_editor/tom_website_editor.dart';

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {
    '/README.md': '# Workspace\n',
    '/config.yaml': 'name: forge\n',
  },
  appName: 'Suite',
  navigatorKey: GlobalKey<NavigatorState>(),
);

Future<List<String>> _openWith(DefaultShellApi shell, String path) async {
  final choices = await shell.editorPicker.choicesFor(
    ForgeContentItem(Uri.file(path)),
  );
  return [for (final choice in choices.choices) choice.id];
}

/// The modules written against the kit alone (not the shell's own).
List<ForgeKitModule> _kitOnly(DefaultShellApi shell) => [
  for (final module in shell.modules.allKitModules)
    if (module is! ForgeModule) module,
];

const _heavyChoiceIds = [
  ForgePdfiumModule.pdfiumChoiceId,
  ForgePdfJsModule.pdfJsChoiceId,
  ForgeOfficeLokModule.lokChoiceId,
  ForgeZetaOfficeModule.choiceId,
];

void main() {
  test('ML-1: by default the suite has every module, in the order Tom Forge '
      'registers them', () async {
    final shell = _shell();
    addTearDown(shell.dispose);
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/',
      restoreApplications: false,
    );
    expect(suite.modules, ForgeSuiteModule.all);
    expect(ForgeSuiteModule.all, ForgeSuiteModule.values.toSet());
    for (final module in ForgeSuiteModule.values) {
      expect(suite.has(module), isTrue, reason: module.name);
    }
    expect(_kitOnly(shell), [
      suite.fileExplorerModule,
      suite.problemsViewModule,
      suite.searchViewModule,
      suite.outlineViewModule,
      suite.outputViewModule,
      suite.revisionViewModule,
      suite.quickOpenModule,
      suite.commandPaletteModule,
      suite.terminalModule,
      suite.officeLokModule,
      suite.officeZetaOfficeModule,
      suite.pdfiumModule,
      suite.pdfJsModule,
    ]);
    expect(
      suite.fileEditorsModule.fileKinds.kinds.map((k) => k.id),
      forgeSuiteFileKinds.map((k) => k.id),
    );
    expect(
      await _openWith(shell, '/docs/report.pdf'),
      containsAllInOrder([
        ForgePdfiumModule.pdfiumChoiceId,
        ForgePdfJsModule.pdfJsChoiceId,
      ]),
    );
  });

  test('ML-2: the YAML editor and the file explorer alone — only they are '
      'registered, the rest is absent, Open With lists only them', () async {
    final shell = _shell();
    addTearDown(shell.dispose);
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/',
      restoreApplications: false,
      modules: const {
        ForgeSuiteModule.yamlFileKind,
        ForgeSuiteModule.fileExplorer,
      },
    );
    expect(suite.modules, {
      ForgeSuiteModule.fileExplorer,
      ForgeSuiteModule.yamlFileKind,
    });
    expect(suite.has(ForgeSuiteModule.pdfium), isFalse);

    // The kit modules: the file explorer alone.
    final kitModules = _kitOnly(shell);
    expect(kitModules, [suite.fileExplorerModule]);
    expect(kitModules.whereType<ForgeFileExplorerModule>(), [
      suite.fileExplorerModule,
    ]);
    expect(kitModules.whereType<ForgePdfiumModule>(), isEmpty);
    expect(kitModules.whereType<ForgePdfJsModule>(), isEmpty);
    expect(kitModules.whereType<ForgeOfficeLokModule>(), isEmpty);
    expect(kitModules.whereType<ForgeZetaOfficeModule>(), isEmpty);
    // The shell's own modules: the shell, the app and the file editors.
    expect(shell.modules.allModules, [
      suite.shellModule,
      suite.appModule,
      suite.fileEditorsModule,
    ]);
    expect(shell.modules.allModules.whereType<WebsiteEditorModule>(), isEmpty);
    expect(shell.modules.allModules.whereType<ForgeQuestsModule>(), isEmpty);
    expect(shell.applications.hasFactory(questApplicationKind), isFalse);

    // A module left out has no instance: its getter says so.
    for (final getter in <Object Function()>[
      () => suite.pdfiumModule,
      () => suite.pdfJsModule,
      () => suite.officeLokModule,
      () => suite.officeZetaOfficeModule,
      () => suite.websiteModule,
      () => suite.questsModule,
      () => suite.terminalModule,
      () => suite.searchViewModule,
      () => suite.quickOpenModule,
    ]) {
      expect(getter, throwsStateError);
    }

    // The file editors: the YAML kind, not the Markdown one.
    expect(suite.fileEditorsModule.fileKinds.kinds.map((k) => k.id), [
      forgeYamlFileKind.id,
    ]);
    final yaml = await _openWith(shell, '/config.yaml');
    expect(yaml.first, forgeYamlFileKind.id);
    expect(yaml, isNot(contains(forgeMarkdownFileKind.id)));
    final md = await _openWith(shell, '/README.md');
    expect(md, isNot(contains(forgeMarkdownFileKind.id)));
    for (final path in ['/docs/report.pdf', '/docs/report.docx']) {
      final ids = await _openWith(shell, path);
      for (final heavy in _heavyChoiceIds) {
        expect(ids, isNot(contains(heavy)), reason: '$path: $heavy');
      }
    }

    // The tom_forge application: the explorer, no Website / Web Preview /
    // Terminal tabs.
    final layout = suite.forgeApplication.layout as PanelLayout;
    final titles = [
      for (final panel in [
        layout.leftPanel,
        layout.rightPanel,
        layout.bottomPanel,
      ])
        for (final tab in panel.tabs) tab.title,
    ];
    expect(titles, isNot(contains('Website')));
    expect(titles, isNot(contains('Web Preview')));
    expect(
      layout.bottomPanel.tabs.where((tab) => tab.terminalSections),
      isEmpty,
    );
    expect(layout.leftPanel.tabs, isNotEmpty, reason: 'the explorer');
  });

  test('ML-3: LibreOfficeKit without ZetaOffice has no alternative route; '
      'Open With lists LibreOfficeKit alone', () async {
    final shell = _shell();
    addTearDown(shell.dispose);
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/',
      restoreApplications: false,
      modules: const {ForgeSuiteModule.officeLok},
    );
    expect(suite.officeLokModule.alternative, isNull);
    expect(() => suite.officeZetaOfficeModule, throwsStateError);
    final ids = await _openWith(shell, '/docs/report.docx');
    expect(ids, contains(ForgeOfficeLokModule.lokChoiceId));
    expect(ids, isNot(contains(ForgeZetaOfficeModule.choiceId)));
  });

  test(
    'ML-4: a given office module is used only when the list names it',
    () async {
      final shell = _shell();
      addTearDown(shell.dispose);
      final office = ForgeOfficeLokModule(
        detect: (_) async =>
            const LibreOfficeInstallation(state: LibreOfficeState.missing),
        libreOfficePath: () => '',
        cleanUpHelpers: () async {},
      );
      final suite = await composeForgeSuite(
        shell: shell,
        workspaceRoot: '/',
        restoreApplications: false,
        modules: const {ForgeSuiteModule.pdfium},
        officeLokModule: office,
      );
      expect(shell.modules.allKitModules, isNot(contains(office)));
      expect(() => suite.officeLokModule, throwsStateError);
      expect(suite.pdfiumModule, isA<ForgePdfiumModule>());
    },
  );
}
