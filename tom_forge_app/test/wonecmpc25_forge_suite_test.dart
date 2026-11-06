/// Tom Forge as a library (wonecmpc25): `composeForgeSuite` puts Forge's
/// modules and the tom_forge application on a shell and adds what an
/// extension brings — here a stand-in module and a full-screen application
/// laid out from its view, as Webforge adds the Webwork application. Tom
/// Forge's own app is the launcher with no extensions. An app built on the
/// library reads the Dart editor's summaries under this package's prefix, and
/// its extension modules route dialogs through the suite's navigator
/// (wonecmpc33). Every app built on it has the quest applications
/// (qim_none-4): the tom_forge application offers the quest picker.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_app/forge_suite.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

class _StandInView extends ForgeView {
  @override
  final ValueListenable<String> title = ValueNotifier('Stand-in');
  @override
  final ValueListenable<String?> titleExtension = ValueNotifier(null);
  @override
  IconData get icon => Icons.extension;
  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();
  @override
  Widget buildMain(BuildContext context) => const Text('stand-in view');
  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _StandInModule extends ForgeModule {
  final view = _StandInView();
  ForgeShellApi? shell;

  @override
  String get displayName => 'Stand-in';
  @override
  void activate(ForgeShellApi shell) => this.shell = shell;
  @override
  void deactivate() {}
  @override
  List<ForgeEditor> get editors => const [];
  @override
  List<ForgeView> get views => [view];
  @override
  List<ForgeAction> get actions => const [];
  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {'/README.md': '# Workspace\n'},
  appName: 'Suite',
  navigatorKey: GlobalKey<NavigatorState>(),
);

void main() {
  test('FS-1: Tom Forge alone — its four modules and its application',
      () async {
    final shell = _shell();
    addTearDown(shell.dispose);
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/',
      restoreApplications: false,
    );
    expect(shell.modules.allModules, containsAll(<ForgeModule>[
      suite.shellModule,
      suite.appModule,
      suite.websiteModule,
      suite.questsModule,
    ]));
    expect(suite.websiteModule, isA<WebsiteEditorModule>());
    expect(shell.applications.hasFactory(questApplicationKind), isTrue);
    expect(shell.applications.all.map((a) => a.id), [forgeApplicationId]);
    expect(suite.forgeApplication.layout, isA<PanelLayout>());
    expect(suite.extensionModules, isEmpty);
  });

  test('FS-2: an extension\'s module is activated and registered after '
      'Forge\'s, and its application is added after the tom_forge one',
      () async {
    final shell = _shell();
    addTearDown(shell.dispose);
    final module = _StandInModule();
    late ForgeSuite seen;
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/',
      restoreApplications: false,
      extensions: [
        ForgeSuiteExtension(
          modules: (_) => [module],
          applications: (s) {
            seen = s;
            return [
              ForgeApplication(
                id: 'stand-in',
                title: 'Stand-in',
                layout: FullScreenLayout(view: module.view),
              ),
            ];
          },
        ),
      ],
    );
    expect(module.shell, same(shell), reason: 'activated on the shell');
    // Forge's own modules, the extension's, then the file editors — so a
    // module that opens its own files is asked before them.
    final modules = shell.modules.allModules.toList();
    expect(modules.indexOf(module),
        greaterThan(modules.indexOf(suite.questsModule)));
    expect(modules.last, same(suite.fileEditorsModule));
    expect(modules[modules.length - 2], same(module));
    expect(suite.extensionModules, [module]);
    expect(shell.applications.all.map((a) => a.id), [forgeApplicationId, 'stand-in']);
    expect(suite.extensionApplications.single.id, 'stand-in');
    expect(seen.appModule, same(suite.appModule), reason: 'Forge\'s modules are there');
  });

  testWidgets('FS-3: the launcher opens on the welcome page under the app\'s '
      'name', (tester) async {
    await tester.pumpWidget(const ForgeSuiteLauncher(appName: 'Webforge test'));
    expect(find.byType(WorkspaceWelcomePage), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Webforge test');
  });

  test('FS-5: the tom_forge application offers the quest picker over the '
      'workspace\'s quests; a quest opens once', () async {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/ws/_ai/quests/alpha/overview.alpha.md': '# alpha',
        '/ws/_ai/quests/beta/overview.beta.md': '# beta',
      },
      appName: 'Suite',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    addTearDown(shell.dispose);
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/ws',
      restoreApplications: false,
    );
    expect(shell.applications.active!.id, forgeApplicationId);
    expect(shell.isActionEnabled(forgeOpenQuestActionId), isTrue);
    expect(await suite.questsModule.quests(), ['alpha', 'beta']);

    final alpha = suite.questsModule.openQuest('alpha');
    expect(questOf(alpha), 'alpha');
    expect(shell.applications.active, same(alpha));
    expect(shell.isActionEnabled(forgeOpenQuestActionId), isTrue,
        reason: 'the picker is there in a quest application too');
    shell.applications.activate(forgeApplicationId);
    expect(suite.questsModule.openQuest('alpha'), same(alpha));
    expect(shell.applications.all.map((a) => a.id),
        [forgeApplicationId, alpha.id]);
  });

  test('FS-4: the suite carries the navigator its extensions route dialogs '
      'through, and points the Dart editor at the summaries it was given',
      () async {
    final shell = _shell();
    addTearDown(shell.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();
    final suite = await composeForgeSuite(
      shell: shell,
      workspaceRoot: '/',
      navigatorKey: navigatorKey,
      dartSummaryAssets: forgeSuiteDartSummaries,
      restoreApplications: false,
    );
    expect(suite.navigatorKey, same(navigatorKey));
    final assets = (shell.layout as DefaultLayoutController).dartSummaryAssets;
    expect(assets.sdkSummary, 'packages/tom_forge_app/assets/sdk_summary.sum');
    expect(assets.packageSummary, 'packages/tom_forge_app/assets/packages.sum');

    final own = _shell();
    addTearDown(own.dispose);
    await composeForgeSuite(
        shell: own, workspaceRoot: '/', restoreApplications: false);
    expect((own.layout as DefaultLayoutController).dartSummaryAssets,
        same(ForgeDartSummaryAssets.root),
        reason: 'Tom Forge\'s own app reads the summaries it carries');
  });
}
