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
export 'src/forge_launch.dart';
// The office editors, one module per route: LibreOfficeKit
// (`suite.officeLokModule`, the default) and ZetaOffice
// (`suite.officeZetaOfficeModule`).
export 'package:tom_forge_office_lok/tom_forge_office_lok.dart'
    show
        ForgeOfficeAlternativeRoute,
        ForgeOfficeLokModule,
        LibreOfficeInstallation,
        LibreOfficeState;
export 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart'
    show ForgeZetaOfficeModule;
// The PDF editors, one module per engine: PDFium (`suite.pdfiumModule`, the
// default) and pdf.js (`suite.pdfJsModule`).
export 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart'
    show ForgePdfiumModule;
export 'package:tom_forge_pdf_pdfjs/tom_forge_pdf_pdfjs.dart'
    show ForgePdfJsModule;
// The file editors (`suite.fileEditorsModule`) and what an extension's
// `fileEditorBuilders` names.
export 'package:tom_forge_file_editors/tom_forge_file_editors.dart'
    show
        ForgeFileEditorAlternative,
        ForgeFileEditorBuilder,
        ForgeFileEditorsModule,
        ForgeFileKind,
        ForgeFileKindRegistry,
        ForgeKitFileKind;
// The Markdown and YAML file kinds the suite registers
// ([forgeSuiteFileKinds]).
export 'package:tom_forge_md_editor/tom_forge_md_editor.dart'
    show forgeMarkdownFileKind;
export 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart'
    show forgeYamlFileKind;
// The quest applications every app built on Forge has (`suite.questsModule`).
export 'package:tom_forge_quests/tom_forge_quests.dart'
    show
        ForgeQuestsModule,
        forgeOpenQuestActionId,
        questApplicationKind,
        questOf;
