import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_office_lok/tom_forge_office_lok.dart'
    show kForgeOfficeDebug;
import 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart'
    show kForgeZetaOfficeDebug;
import 'package:tom_forge_pdf_pdfium/tom_forge_pdf_pdfium.dart'
    show kForgePdfiumDebug;
import 'package:tom_forge_pdf_pdfjs/tom_forge_pdf_pdfjs.dart'
    show kForgePdfJsDebug;
import 'package:tom_office_editor/tom_office_editor.dart'
    show kOfficeEditorDebug;
import 'package:tom_office_zetaoffice/tom_office_zetaoffice.dart'
    show kZetaOfficeDebug;
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
  useForgeCodeHighlighting();
  final launch = ForgeLaunch.parse(arguments);
  if (launch.trails.contains('pdf')) {
    kForgePdfiumDebug = true;
    kForgePdfJsDebug = true;
    kPdfEditorDebug = true;
  }
  if (launch.trails.contains('office')) {
    kForgeOfficeDebug = true;
    kForgeZetaOfficeDebug = true;
    kOfficeEditorDebug = true;
    kZetaOfficeDebug = true;
  }
  runApp(
    ForgeSuiteLauncher(
      workspace: launch.workspace,
      onComposed: launch.openDocuments,
    ),
  );
}
