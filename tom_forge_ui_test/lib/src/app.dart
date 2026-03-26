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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: widget.application.title,
      navigatorKey: widget.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
