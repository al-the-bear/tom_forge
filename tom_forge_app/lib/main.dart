import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_pdf_editors/tom_forge_pdf_editors.dart'
    show kForgePdfDebug;
import 'package:tom_pdf_editor/tom_pdf_editor.dart' show kPdfEditorDebug;

import 'forge_suite.dart';

/// Tom Forge: the welcome page, or the folder and files the command line
/// names ([ForgeLaunch]).
void main(List<String> arguments) {
  if (Platform.isLinux) {
    // Linux WebView defaults to software rendering in the local plugin fork.
    debugPrint(
      '[tom_forge_app] Linux WebView defaults to software rendering. '
      'Set FLUTTER_INAPPWEBVIEW_LINUX_FORCE_GL=1 to force hardware mode for diagnostics.',
    );
  }
  final launch = ForgeLaunch.parse(arguments);
  if (launch.trails.contains('pdf')) {
    kForgePdfDebug = true;
    kPdfEditorDebug = true;
  }
  runApp(
    ForgeSuiteLauncher(
      workspace: launch.workspace,
      onComposed: launch.openDocuments,
    ),
  );
}
