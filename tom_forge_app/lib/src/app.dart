import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Root widget for the Tom Forge IDE.
class ForgeApp extends StatefulWidget {
  final DefaultShellApi shell;
  final ForgeApplication application;
  final GlobalKey<NavigatorState> navigatorKey;
  final void Function(Directory) onWorkspaceSelected;

  const ForgeApp({
    super.key,
    required this.shell,
    required this.application,
    required this.navigatorKey,
    required this.onWorkspaceSelected,
  });

  @override
  State<ForgeApp> createState() => _ForgeAppState();
}

class _ForgeAppState extends State<ForgeApp> {
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
              onOpenFolder: widget.onWorkspaceSelected,
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
