import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Root widget for the Tom Forge IDE.
class ForgeApp extends StatelessWidget {
  final DefaultShellApi shell;
  final GlobalKey<NavigatorState> navigatorKey;
  final void Function(Directory) onWorkspaceSelected;
  final bool workspaceReady;

  /// The window title.
  final String title;

  const ForgeApp({
    super.key,
    this.title = 'Tom Forge',
    required this.shell,
    required this.navigatorKey,
    required this.onWorkspaceSelected,
    required this.workspaceReady,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: title,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: workspaceReady
          ? ForgeShellScaffold(
              shell: shell,
              layoutController: shell.layout as DefaultLayoutController,
              systemState: shell.systemState as DefaultSystemState,
              statusBarController: shell.statusBar,
              notificationManager:
                  shell.notifications as DefaultNotificationManager,
              onOpenFolder: onWorkspaceSelected,
            )
          : WorkspaceWelcomePage(onFolderSelected: onWorkspaceSelected),
    );
  }
}
