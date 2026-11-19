import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Root widget for the Forge Test IDE.
class ForgeTestApp extends StatefulWidget {
  final DefaultShellApi shell;
  final GlobalKey<NavigatorState> navigatorKey;
  final void Function(Directory) onWorkspaceSelected;

  const ForgeTestApp({
    super.key,
    required this.shell,
    required this.navigatorKey,
    required this.onWorkspaceSelected,
  });

  @override
  State<ForgeTestApp> createState() => _ForgeTestAppState();
}

class _ForgeTestAppState extends State<ForgeTestApp> {
  bool _workspaceSelected = false;
  final ForgePreferencesService _preferences = ForgePreferencesService.instance;

  @override
  void initState() {
    super.initState();
    _preferences.addListener(_onPreferencesChanged);
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  void _onPreferencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = _preferences.highContrast;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Forge Test IDE',
      navigatorKey: widget.navigatorKey,
      themeMode: _preferences.themeMode,
      theme: forgeThemeData(Brightness.light, highContrast: highContrast),
      darkTheme: forgeThemeData(Brightness.dark, highContrast: highContrast),
      highContrastTheme: forgeThemeData(Brightness.light, highContrast: true),
      highContrastDarkTheme: forgeThemeData(
        Brightness.dark,
        highContrast: true,
      ),
      home: _workspaceSelected
          ? ForgeShellScaffold(
              shell: widget.shell,
              layoutController: widget.shell.layout as DefaultLayoutController,
              systemState: widget.shell.systemState as DefaultSystemState,
              statusBarController: widget.shell.statusBar,
              notificationManager:
                  widget.shell.notifications as DefaultNotificationManager,
            )
          : WorkspaceWelcomePage(
              onFolderSelected: (directory) {
                setState(() => _workspaceSelected = true);
                widget.onWorkspaceSelected(directory);
              },
            ),
    );
  }
}
