import 'dart:io';

import 'package:flutter/material.dart';

import 'forge_suite.dart';

void main() {
  if (Platform.isLinux) {
    // Linux WebView defaults to software rendering in the local plugin fork.
    debugPrint(
      '[tom_forge_app] Linux WebView defaults to software rendering. '
      'Set FLUTTER_INAPPWEBVIEW_LINUX_FORCE_GL=1 to force hardware mode for diagnostics.',
    );
  }
  runApp(const ForgeSuiteLauncher());
}
