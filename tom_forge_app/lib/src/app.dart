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
    // The theme follows the user's theme mode and high-contrast preference
    // (and, for System, the platform); ForgeShellTheme is installed in each.
    final preferences = ForgePreferencesService.instance;
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => _buildApp(preferences),
    );
  }

  Widget _buildApp(ForgePreferencesService preferences) {
    final highContrast = preferences.highContrast;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: title,
      navigatorKey: navigatorKey,
      themeMode: preferences.themeMode,
      theme: forgeThemeData(Brightness.light, highContrast: highContrast),
      darkTheme: forgeThemeData(Brightness.dark, highContrast: highContrast),
      highContrastTheme: forgeThemeData(Brightness.light, highContrast: true),
      highContrastDarkTheme: forgeThemeData(
        Brightness.dark,
        highContrast: true,
      ),
      home: workspaceReady
          ? ForgeShellScaffold(
              shell: shell,
              layoutController: shell.layout as DefaultLayoutController,
              systemState: shell.systemState as DefaultSystemState,
              statusBarController: shell.statusBar,
              notificationManager:
                  shell.notifications as DefaultNotificationManager,
              onOpenFolder: (path) => onWorkspaceSelected(Directory(path)),
            )
          : WorkspaceWelcomePage(onFolderSelected: onWorkspaceSelected),
    );
  }
}
