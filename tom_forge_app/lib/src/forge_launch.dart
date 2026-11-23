import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show ForgePreferencesService;

import 'forge_suite.dart';

/// What Tom Forge's command line asks for: a workspace folder to open at
/// once, files to open in it, and the debug trails to switch on.
///
/// ```bash
/// flutter run -d macos --dart-entrypoint-args --workspace=$HOME/notes
/// flutter run -d macos --dart-entrypoint-args $HOME/notes/report.pdf
/// tom_forge_app.app/Contents/MacOS/tom_forge_app --trail=pdf report.pdf
/// tom_forge_app.app/Contents/MacOS/tom_forge_app --trail=office report.docx
/// ```
@immutable
class ForgeLaunch {
  const ForgeLaunch({
    this.workspace,
    this.documents = const [],
    this.trails = const {},
  });

  /// The folder Forge opens; null shows the welcome page.
  final Directory? workspace;

  /// Files to open once the workspace is up, through Forge's own open path
  /// (each goes to the module whose editor takes it).
  final List<String> documents;

  /// The debug trails to switch on (`pdf`: the PDF editors' `[FP]`, `[PE]`
  /// and `[PE:js]`; `office`: the office editors' `[FO]`, `[OE]` and
  /// `[ZO]`).
  final Set<String> trails;

  /// Reads [arguments]: `--workspace=<folder>` (or `--workspace <folder>`)
  /// names the folder, `--trail=<name>[,<name>]` switches trails on, every
  /// other argument not starting with `-` is a file to open. With files and
  /// no folder, the folder is the first file's.
  factory ForgeLaunch.parse(List<String> arguments) {
    String? workspace;
    final documents = <String>[];
    final trails = <String>{};
    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument.startsWith('--workspace=')) {
        workspace = argument.substring('--workspace='.length);
      } else if (argument == '--workspace' && i + 1 < arguments.length) {
        workspace = arguments[++i];
      } else if (argument.startsWith('--trail=')) {
        trails.addAll(
          argument
              .substring('--trail='.length)
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty),
        );
      } else if (!argument.startsWith('-')) {
        documents.add(argument);
      }
    }
    if (workspace == null && documents.isNotEmpty) {
      workspace = File(documents.first).absolute.parent.path;
    }
    return ForgeLaunch(
      workspace: workspace == null ? null : Directory(workspace),
      documents: [for (final d in documents) File(d).absolute.path],
      trails: trails,
    );
  }

  /// Opens the [documents] in [suite] through Forge's own open path, with
  /// the user's file-type defaults ([preferences], default the app's)
  /// applied first: the shell scaffold applies them only when it is first
  /// built, after the documents opened.
  void openDocuments(ForgeSuite suite, {ForgePreferencesService? preferences}) {
    final prefs = preferences ?? ForgePreferencesService.instance;
    if (documents.isNotEmpty && prefs.isLoaded) {
      for (final e in prefs.fileTypeDefaultEditors.entries) {
        suite.shell.setFileTypeDefault(e.key, e.value);
      }
    }
    if (trails.isNotEmpty) {
      debugPrint(
        '[launch] ${documents.length} file(s); preferences '
        '${prefs.isLoaded ? 'loaded' : 'not loaded'}, file-type defaults '
        '${prefs.fileTypeDefaultEditors}',
      );
    }
    for (final path in documents) {
      final uri = FileSystemEntity.isDirectorySync(path)
          ? Uri.directory(path)
          : Uri.file(path);
      suite.shell.layout.openFile(uri);
    }
  }
}
