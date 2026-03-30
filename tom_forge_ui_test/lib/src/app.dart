import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Root widget for the Forge Test IDE.
class ForgeTestApp extends StatefulWidget {
  final DefaultShellApi shell;
  final ForgeApplication application;
  final GlobalKey<NavigatorState> navigatorKey;
  final void Function(Directory) onWorkspaceSelected;

  const ForgeTestApp({
    super.key,
    required this.shell,
    required this.application,
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

  ThemeData _buildThemeData(ThemeMode mode) {
    final brightness =
        mode == ThemeMode.light ? Brightness.light : Brightness.dark;
    final shellTheme = ForgeShellTheme.forMode(mode);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      ),
      useMaterial3: true,
      extensions: <ThemeExtension>[shellTheme],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _preferences.themeMode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: widget.application.title,
      navigatorKey: widget.navigatorKey,
      theme: _buildThemeData(themeMode),
      home: _workspaceSelected
          ? ForgeShellScaffold(
              shell: widget.shell,
              application: widget.application,
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
