/// Tom Forge with all of its functionality, as a library an app starts from:
/// Tom Forge's own app is [ForgeSuiteLauncher] with no extensions, and an app
/// built on Forge (Webforge) adds its modules and applications through
/// [ForgeSuiteExtension]s.
///
/// Forge's licence direction holds: this library, like every Forge package,
/// names no Webwork package — a host adds its own.
library;

export 'src/app.dart' show ForgeApp;
export 'src/forge_app_module.dart' show ForgeAppModule;
export 'src/forge_suite.dart';
// The file editors (`suite.fileEditorsModule`) and what an extension's
// `fileEditorBuilders` names.
export 'package:tom_forge_file_editors/tom_forge_file_editors.dart'
    show ForgeFileEditorBuilder, ForgeFileEditorsModule, ForgeFileKind;
// The quest applications every app built on Forge has (`suite.questsModule`).
export 'package:tom_forge_quests/tom_forge_quests.dart'
    show ForgeQuestsModule, forgeOpenQuestActionId, questApplicationKind, questOf;
