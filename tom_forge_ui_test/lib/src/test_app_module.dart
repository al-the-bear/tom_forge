import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show DefaultNotificationManager, ForgeDiagnostic, ForgeDiagnosticCollection, ForgeErrorCodes, ForgeOutputChannel, ForgePanelLocation, ForgeRetryPolicy, ForgeSeverity, ForgeTextPosition, ForgeTextRange;
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Test IDE module providing views, actions, shortcuts, and status bar items.
class TestAppModule extends ForgeModule {
  TestAppModule({
    required Uri workspaceRootUri,
    this.enableSampleDiagnostics = false,
  }) : _workspaceRootUri = workspaceRootUri;

  final Uri _workspaceRootUri;
  final bool enableSampleDiagnostics;
  late ForgeShellApi _shell;
  final List<ForgeView> _views = [];
  final List<ForgeAction> _actions = [];
  final List<ForgeShortcutBinding> _shortcuts = [];
  final List<StatusBarItem> _statusBarItems = [];

  final _cursorText = ValueNotifier<String>('Ln 1, Col 1');
  final _encodingText = ValueNotifier<String>('UTF-8');
  final _languageText = ValueNotifier<String>('Plain Text');
  final _diagnosticText = ValueNotifier<String>('0 errors, 0 warnings');
  final _notificationText = ValueNotifier<String>('0 messages');
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  VoidCallback? _cursorPositionListener;
  VoidCallback? _notificationHistoryListener;

  ForgeDiagnosticCollection? _diagnosticCollection;
  ForgeOutputChannel? _buildChannel;
  DartOutlineProvider? _outlineProvider;
  ModifiedFileDecorationProvider? _decorationProvider;
  ForgeDisposable? _outlineRegistration;
  ForgeDisposable? _decorationRegistration;

  @override
  String get displayName => 'Test IDE';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    _buildViews();
    _buildActions();
    _buildShortcuts();
    _buildStatusBarItems();
    _listenToStateChanges();
    _setupDiagnosticsAndOutput();
    _createDefaultTerminal();
    _registerProviders();
    _restoreModuleState();
    _logShellModuleCapabilities();
  }

  @override
  void deactivate() {
    _saveModuleState();
    _outlineRegistration?.dispose();
    _outlineRegistration = null;
    _outlineProvider?.dispose();
    _outlineProvider = null;
    _decorationRegistration?.dispose();
    _decorationRegistration = null;
    _decorationProvider?.dispose();
    _decorationProvider = null;
    if (_cursorPositionListener != null) {
      _cursorPositionListener!();
      _cursorPositionListener = null;
    }
    if (_notificationHistoryListener != null) {
      final nm = _shell.notifications;
      if (nm is DefaultNotificationManager) {
        nm.history.removeListener(_notificationHistoryListener!);
      }
      _notificationHistoryListener = null;
    }
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _cursorText.dispose();
    _encodingText.dispose();
    _languageText.dispose();
    _diagnosticText.dispose();
    _notificationText.dispose();
    _views.clear();
    _actions.clear();
    _shortcuts.clear();
    _statusBarItems.clear();
  }

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => List.unmodifiable(_views);

  @override
  List<ForgeAction> get actions => List.unmodifiable(_actions);

  @override
  List<ForgeShortcutBinding> get shortcuts => List.unmodifiable(_shortcuts);

  @override
  List<StatusBarItem> get statusBarItems => List.unmodifiable(_statusBarItems);

  @override
  List<ForgeShortcutMenu> get shortcutMenus {
    final byId = {for (final a in _actions) a.id: a};
    return [
      // Explorer shortcut menu (concept §11.4).
      ForgeShortcutMenu(
        triggerKey: LogicalKeyboardKey.keyE,
        label: 'Explorer',
        entries: [
          ForgeShortcutMenuEntry(
            key: LogicalKeyboardKey.keyR,
            action: byId['view.toggleExplorer']!,
          ),
          ForgeShortcutMenuEntry(
            key: LogicalKeyboardKey.keyN,
            action: byId['file.save']!,
          ),
          ForgeShortcutMenuEntry(
            key: LogicalKeyboardKey.keyD,
            action: byId['file.saveAll']!,
          ),
          ForgeShortcutMenuEntry(
            key: LogicalKeyboardKey.keyC,
            action: byId['file.closeAll']!,
          ),
        ],
      ),
    ];
  }

  // ── Views ──

  void _buildViews() {
    _views.addAll([
      ForgeFileExplorerView(
        fileSystem: _shell.fileSystem,
        layoutController: _shell.layout,
        rootUri: _workspaceRootUri,
        contextMenus: _shell.contextMenus,
        systemState: _shell.systemState as DefaultSystemState,
        fileDecorationManager:
            _shell.fileDecorations as DefaultFileDecorationManager,
      ),
      ForgeOutlineView(
        outlineManager: _shell.outline as DefaultOutlineManager,
        systemState: _shell.systemState,
      ),
      ForgeProblemsView(
        diagnosticManager: _shell.diagnostics,
        layoutController: _shell.layout,
      ),
      ForgeOutputView(channelManager: _shell.output),
      ForgeSearchView(
        searchManager: _shell.search,
        layoutController: _shell.layout,
        systemState: _shell.systemState as DefaultSystemState,
      ),
    ]);
  }

  // ── Actions ──

  void _buildActions() {
    final fileSave = ForgeAction(
      id: 'file.save',
      label: 'Save',
      icon: Icons.save,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor != null) {
          try {
            final content = editor.getContent();
            if (content != null) {
              await ForgeRetryPolicy.withImmediateRetry(
                operation: () => _shell.fileSystem.writeText(editor.uri, content),
                maxAttempts: 2,
              );
            }
            await _shell.fileSystem.save(editor.uri);
            editor.markClean();
          } catch (e) {
            final action = await _shell.notifications.showError(
              'Save failed: $e',
              actions: ['Retry', 'Save As...'],
            );
            if (action == 'Retry') {
              _shell.executeAction('file.save');
            } else if (action == 'Save As...') {
              _shell.executeAction('file.saveAs');
            }
            _emitFileErrorDiagnostic(
              editor.uri,
              ForgeErrorCodes.fsFileNotFound,
              'File write error: $e',
            );
          }
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final fileSaveAll = ForgeAction(
      id: 'file.saveAll',
      label: 'Save All',
      icon: Icons.save_alt,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        for (final editor in _shell.systemState.dirtyEditors) {
          try {
            final content = editor.getContent();
            if (content != null) {
              await _shell.fileSystem.writeText(editor.uri, content);
            }
            await _shell.fileSystem.save(editor.uri);
            editor.markClean();
          } catch (e) {
            _shell.notifications.showError(
              'Save failed for ${editor.uri.pathSegments.last}: $e',
            );
          }
        }
        return null;
      },
      isEnabled: () => _shell.systemState.hasUnsavedChanges,
      isVisible: () => true,
    );

    final fileClose = ForgeAction(
      id: 'file.close',
      label: 'Close Tab',
      icon: Icons.close,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor != null) {
          final layout = _shell.layout;
          if (layout is DefaultLayoutController) {
            layout.closeEditor(editor);
          }
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final fileCloseAll = ForgeAction(
      id: 'file.closeAll',
      label: 'Close All Tabs',
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final layout = _shell.layout;
        if (layout is DefaultLayoutController) {
          layout.closeAllEditors();
        }
        return null;
      },
      isEnabled: () => _shell.systemState.openEditors.isNotEmpty,
      isVisible: () => true,
    );

    final editUndo = ForgeAction(
      id: 'edit.undo',
      label: 'Undo',
      icon: Icons.undo,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _shell.undoManager.undo();
        return null;
      },
      isEnabled: () => _shell.undoManager.canUndo.value,
      isVisible: () => true,
    );

    final editRedo = ForgeAction(
      id: 'edit.redo',
      label: 'Redo',
      icon: Icons.redo,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _shell.undoManager.redo();
        return null;
      },
      isEnabled: () => _shell.undoManager.canRedo.value,
      isVisible: () => true,
    );

    final editFindInFiles = ForgeAction(
      id: 'edit.findInFiles',
      label: 'Find in Files',
      icon: Icons.search,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _shell.layout.togglePanel(ForgePanelLocation.left);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final editorFind = ForgeAction(
      id: 'editor.find',
      label: 'Find',
      icon: Icons.find_in_page,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor != null) {
          _shell.notifications.showInformation('Find in ${editor.title}');
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final editorDeleteLine = ForgeAction(
      id: 'editor.deleteLine',
      label: 'Delete Line',
      icon: Icons.remove_circle_outline,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor != null) {
          _shell.notifications.showInformation('Delete line in ${editor.title}');
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final viewToggleExplorer = ForgeAction(
      id: 'view.toggleExplorer',
      label: 'Toggle Explorer',
      icon: Icons.folder_outlined,
      menu: ForgeMenuLocation.view,
      execute: (_) async {
        _shell.layout.togglePanel(ForgePanelLocation.left);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final viewToggleOutline = ForgeAction(
      id: 'view.toggleOutline',
      label: 'Toggle Outline',
      icon: Icons.account_tree,
      menu: ForgeMenuLocation.view,
      execute: (_) async {
        _shell.layout.togglePanel(ForgePanelLocation.right);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final viewToggleProblems = ForgeAction(
      id: 'view.toggleProblems',
      label: 'Toggle Problems',
      icon: Icons.error_outline,
      menu: ForgeMenuLocation.view,
      execute: (_) async {
        _shell.layout.togglePanel(ForgePanelLocation.bottom);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final viewToggleOutput = ForgeAction(
      id: 'view.toggleOutput',
      label: 'Toggle Output',
      icon: Icons.terminal,
      menu: ForgeMenuLocation.view,
      execute: (_) async {
        _shell.layout.togglePanel(ForgePanelLocation.bottom);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final viewToggleTerminal = ForgeAction(
      id: 'view.toggleTerminal',
      label: 'Toggle Terminal',
      icon: Icons.code,
      menu: ForgeMenuLocation.view,
      execute: (_) async {
        _shell.layout.togglePanel(ForgePanelLocation.bottom);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final viewNewTerminal = ForgeAction(
      id: 'view.newTerminal',
      label: 'New Terminal',
      icon: Icons.add,
      menu: ForgeMenuLocation.view,
      execute: (_) async {
        _shell.terminals.create();
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final viewSplitEditor = ForgeAction(
      id: 'view.splitEditor',
      label: 'Split Editor',
      icon: Icons.vertical_split,
      menu: ForgeMenuLocation.view,
      execute: (_) async {
        _shell.layout.splitMiddlePanel();
        return null;
      },
      isEnabled: () => _shell.systemState.openEditors.isNotEmpty,
      isVisible: () => true,
    );

    final helpAbout = ForgeAction(
      id: 'help.about',
      label: 'About',
      icon: Icons.info_outline,
      menu: ForgeMenuLocation.help,
      execute: (_) async {
        _shell.notifications.showInformation('Forge Test IDE v1.0.0');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final helpReportIssue = ForgeAction(
      id: 'help.reportIssue',
      label: 'Report Issue...',
      icon: Icons.bug_report,
      menu: ForgeMenuLocation.help,
      execute: (_) async {
        final action = await _shell.notifications.showWarning(
          'Would you like to include workspace info in the report?',
          actions: ['Include Info', 'Skip', 'Cancel'],
        );
        if (action != null && action != 'Cancel') {
          _shell.notifications.showInformation(
            'Issue report submitted (info: ${action == 'Include Info'})',
          );
        }
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    // ── Terminal wiring actions ──

    final terminalRunActiveFile = ForgeAction(
      id: 'terminal.runActiveFile',
      label: 'Run Active File in Terminal',
      icon: Icons.play_arrow,
      menu: ForgeMenuLocation.run,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor == null) return null;
        final fileName = editor.uri.pathSegments.last;
        // Create or reuse the active terminal.
        final terminal = _shell.terminals.activeTerminal ??
            _shell.terminals.create(
              name: 'Run: $fileName',
              shellPath: '/bin/bash',
              cwd: _shell.systemState.workspaceRootPath,
            );
        // Track execution via execution monitor.
        final execId = 'run_${DateTime.now().millisecondsSinceEpoch}';
        _shell.executions.start(id: execId, label: 'Run $fileName');
        terminal.sendText('echo "Running $fileName..."');
        terminal.show();
        _shell.layout.openPanel(ForgePanelLocation.bottom);
        // Mark execution as completed after dispatch.
        _shell.executions.complete(execId);
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final terminalSendCommand = ForgeAction(
      id: 'terminal.sendCommand',
      label: 'Send Command to Terminal',
      icon: Icons.send,
      execute: (_) async {
        final command = await _shell.dialogs.showInputBox(
          prompt: 'Send to Terminal',
          placeholder: 'Enter command',
        );
        if (command != null && command.isNotEmpty) {
          final terminal = _shell.terminals.activeTerminal ??
              _shell.terminals.create(
                name: 'bash',
                shellPath: '/bin/bash',
              );
          terminal.sendText(command);
          terminal.show();
        }
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final terminalCloseActive = ForgeAction(
      id: 'terminal.closeActive',
      label: 'Close Active Terminal',
      icon: Icons.close,
      execute: (_) async {
        final terminal = _shell.terminals.activeTerminal;
        terminal?.close();
        return null;
      },
      isEnabled: () => _shell.terminals.activeTerminal != null,
      isVisible: () => true,
    );

    final terminalShowActive = ForgeAction(
      id: 'terminal.show',
      label: 'Show Terminal',
      icon: Icons.terminal,
      execute: (_) async {
        final terminal = _shell.terminals.activeTerminal;
        if (terminal != null) {
          terminal.show();
          _shell.layout.openPanel(ForgePanelLocation.bottom);
        }
        return null;
      },
      isEnabled: () => _shell.terminals.activeTerminal != null,
      isVisible: () => true,
    );

    final helpOpenUrl = ForgeAction(
      id: 'help.openUrl',
      label: 'Open URL...',
      icon: Icons.open_in_browser,
      menu: ForgeMenuLocation.help,
      execute: (_) async {
        final url = await _shell.dialogs.showInputBox(
          prompt: 'Open External URL',
          placeholder: 'https://',
          validateInput: (text) {
            if (text.isEmpty) return 'Enter a URL';
            final uri = Uri.tryParse(text);
            if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
            return null;
          },
        );
        if (url != null) {
          await _shell.environment.openExternal(Uri.parse(url));
          _shell.notifications.showInformation('Opened $url');
        }
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final buildRun = ForgeAction(
      id: 'build.run',
      label: 'Run Build',
      icon: Icons.build,
      menu: ForgeMenuLocation.run,
      execute: (_) async {
        // Create a build terminal with output channel.
        final buildChannel =
            _buildChannel ?? _shell.output.create('Build');
        final terminal = _shell.terminals.create(
          name: 'Build',
          shellPath: '/bin/bash',
          cwd: _shell.systemState.workspaceRootPath,
          outputChannel: buildChannel,
        );
        // Track via execution monitor.
        final execId = 'build_${DateTime.now().millisecondsSinceEpoch}';
        _shell.executions.start(id: execId, label: 'Build');
        buildChannel.appendLine('[Build] Started...');
        terminal.sendText('echo "Building..."');
        terminal.show();
        _shell.layout.openPanel(ForgePanelLocation.bottom);
        // Mark completed.
        _shell.executions.complete(execId);
        buildChannel.appendLine('[Build] Completed.');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final buildStop = ForgeAction(
      id: 'build.stop',
      label: 'Stop Build',
      icon: Icons.stop,
      menu: ForgeMenuLocation.run,
      execute: (_) async {
        // Cancel all running executions.
        for (final execution in _shell.executions.running) {
          _shell.executions.cancel(execution.id);
        }
        _shell.notifications.showInformation('All running tasks cancelled');
        return null;
      },
      isEnabled: () => _shell.executions.running.isNotEmpty,
      isVisible: () => true,
    );

    // Chord-target actions (Ctrl+K → second key).
    final editToggleComment = ForgeAction(
      id: 'edit.toggleComment',
      label: 'Toggle Line Comment',
      icon: Icons.comment,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _shell.notifications.showInformation('Toggle comment triggered');
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final editToggleBlockComment = ForgeAction(
      id: 'edit.toggleBlockComment',
      label: 'Toggle Block Comment',
      icon: Icons.code,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _shell.notifications.showInformation('Toggle block comment triggered');
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final editFormatDocument = ForgeAction(
      id: 'edit.formatDocument',
      label: 'Format Document',
      icon: Icons.format_align_left,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _shell.notifications.showInformation('Format document triggered');
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    // ── Dialog-using actions ──

    final goToLine = ForgeAction(
      id: 'go.line',
      label: 'Go to Line...',
      icon: Icons.format_list_numbered,
      menu: ForgeMenuLocation.go,
      execute: (_) async {
        final result = await _shell.dialogs.showInputBox(
          prompt: 'Go to Line',
          placeholder: 'Type a line number',
          validateInput: (text) {
            if (text.isEmpty) return 'Enter a line number';
            final n = int.tryParse(text);
            if (n == null || n < 1) return 'Enter a valid positive number';
            return null;
          },
        );
        if (result != null) {
          final line = int.tryParse(result);
          if (line != null) {
            _shell.notifications.showInformation('Navigate to line $line');
          }
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final fileNew = ForgeAction(
      id: 'file.new',
      label: 'New File...',
      icon: Icons.note_add,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final name = await _shell.dialogs.showInputBox(
          prompt: 'New File',
          placeholder: 'Enter file name',
          validateInput: (text) {
            if (text.trim().isEmpty) return 'File name cannot be empty';
            if (text.contains(RegExp(r'[/\\]'))) return 'Invalid characters';
            return null;
          },
        );
        if (name != null && name.trim().isNotEmpty) {
          final dir = _shell.systemState.workspaceRootPath;
          final uri = Uri.file('$dir/$name');
          try {
            await _shell.fileSystem.writeText(uri, '');
            _shell.layout.openFile(uri);
            _shell.notifications.showInformation('Created $name');
          } catch (e) {
            _shell.notifications.showError('Failed to create file: $e');
          }
        }
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final fileOpen = ForgeAction(
      id: 'file.open',
      label: 'Open File...',
      icon: Icons.folder_open,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final uris = await _shell.dialogs.showOpenDialog(
          title: 'Open File',
        );
        if (uris != null) {
          for (final uri in uris) {
            _shell.layout.openFile(uri);
          }
        }
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final fileOpenWith = ForgeAction(
      id: 'file.openWith',
      label: 'Open With...',
      icon: Icons.open_in_new,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor == null) return null;
        await _shell.layout.openFileWith(editor.uri);
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final changeLanguageMode = ForgeAction(
      id: 'editor.changeLanguageMode',
      label: 'Change Language Mode',
      icon: Icons.translate,
      execute: (_) async {
        final modes = [
          ForgeQuickPickItem(label: 'Plain Text', value: 'plaintext'),
          ForgeQuickPickItem(label: 'Dart', value: 'dart'),
          ForgeQuickPickItem(label: 'Markdown', value: 'markdown'),
          ForgeQuickPickItem(label: 'YAML', value: 'yaml'),
          ForgeQuickPickItem(label: 'JSON', value: 'json'),
          ForgeQuickPickItem(label: 'HTML', value: 'html'),
          ForgeQuickPickItem(label: 'CSS', value: 'css'),
          ForgeQuickPickItem(label: 'JavaScript', value: 'javascript'),
          ForgeQuickPickItem(label: 'TypeScript', value: 'typescript'),
          ForgeQuickPickItem(label: 'Python', value: 'python'),
          ForgeQuickPickItem(label: 'Shell', value: 'shell'),
        ];
        final mode = await _shell.dialogs.showQuickPick(
          modes,
          placeholder: 'Select Language Mode',
        );
        if (mode != null) {
          _languageText.value = modes.firstWhere((m) => m.value == mode).label;
          _shell.notifications.showInformation('Language mode: $mode');
        }
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final fileSaveAs = ForgeAction(
      id: 'file.saveAs',
      label: 'Save As...',
      icon: Icons.save_as,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor == null) return null;
        final uri = await _shell.dialogs.showSaveDialog(
          title: 'Save As',
          defaultUri: editor.uri,
        );
        if (uri != null) {
          try {
            final content = editor.getContent();
            if (content != null) {
              await _shell.fileSystem.writeText(uri, content);
              editor.markClean();
              _shell.notifications.showInformation(
                'Saved as ${uri.pathSegments.last}',
              );
            }
          } catch (e) {
            _shell.notifications.showError('Save As failed: $e');
          }
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    _actions.addAll([
      fileSave, fileSaveAll, fileNew, fileOpen, fileOpenWith, fileSaveAs,
      fileClose, fileCloseAll,
      editUndo, editRedo, editFindInFiles, editorFind, editorDeleteLine,
      editToggleComment, editToggleBlockComment, editFormatDocument,
      goToLine, changeLanguageMode,
      viewToggleExplorer, viewToggleOutline,
      viewToggleProblems, viewToggleOutput, viewToggleTerminal,
      viewNewTerminal, viewSplitEditor,
      terminalRunActiveFile, terminalSendCommand, terminalCloseActive,
      terminalShowActive,
      buildRun, buildStop,
      helpAbout, helpReportIssue, helpOpenUrl,
    ]);
  }

  // ── Shortcuts ──

  void _buildShortcuts() {
    ForgeShortcutBinding bind(ForgeAction action, ForgeShortcutKey key) =>
        ForgeShortcutBinding(action: action, key: key);

    final byId = {for (final a in _actions) a.id: a};

    // Shell-level shortcuts (forge.commandPalette, forge.toggleLeftPanel, etc.)
    // and standard editing shortcuts (forge.edit.undo, forge.edit.redo, etc.)
    // are provided by TomForgeShellModule.  This module only adds bindings
    // for test-harness–specific actions.
    _shortcuts.addAll([
      // Cmd+Y → Delete line in text editor (concept §11.3).
      bind(byId['editor.deleteLine']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyY, primaryModifier: true)),
      // F5 → Run active file (kept as function key, no modifier).
      bind(byId['terminal.runActiveFile']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.f5)),
      // F6/F7 → Build run/stop (test harness convenience bindings).
      bind(byId['build.run']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.f6)),
      bind(byId['build.stop']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.f7)),
    ]);
  }

  // ── Status bar items ──

  void _buildStatusBarItems() {
    _statusBarItems.addAll([
      StatusBarItem(
        text: _cursorText,
        alignment: StatusBarAlignment.left,
        priority: 100,
        tooltip: 'Cursor Position',
        isActive: (_) => _shell.systemState.activeEditor != null,
        onTap: () {
          _shell.executeAction('go.line');
        },
      ),
      StatusBarItem(
        text: _encodingText,
        alignment: StatusBarAlignment.left,
        priority: 50,
        tooltip: 'File Encoding',
        isActive: (_) => true,
        onTap: () {
          _shell.notifications.showInformation('Encoding: ${_encodingText.value}');
        },
      ),
      StatusBarItem(
        text: _languageText,
        alignment: StatusBarAlignment.center,
        priority: 100,
        tooltip: 'Language Mode',
        isActive: (_) => _shell.systemState.activeEditor != null,
        onTap: () {
          _shell.executeAction('editor.changeLanguageMode');
        },
      ),
      StatusBarItem(
        text: _diagnosticText,
        icon: Icons.error_outline,
        alignment: StatusBarAlignment.right,
        priority: 100,
        tooltip: 'Problems',
        isActive: (_) => true,
        onTap: () {
          // Open the bottom panel to show the problems view.
          _shell.layout.openPanel(ForgePanelLocation.bottom);
        },
      ),
      StatusBarItem(
        text: _notificationText,
        icon: Icons.notifications_none,
        alignment: StatusBarAlignment.right,
        priority: 90,
        tooltip: 'Notifications',
        isActive: (_) => true,
        onTap: () {
          // Toggle notification popup.
          final nm = _shell.notifications;
          if (nm is DefaultNotificationManager) {
            nm.popupVisible.value = !nm.popupVisible.value;
          }
        },
      ),
    ]);
  }

  // ── State listeners ──

  void _listenToStateChanges() {
    _subscriptions.add(
      _shell.systemState.onEditorsChanged.listen((event) {
        _updateLanguageText();
        _updateCursorListener();
      }),
    );

    _subscriptions.add(
      _shell.systemState.onFocusChanged.listen((_) {
        _updateLanguageText();
        _updateCursorListener();
      }),
    );

    _subscriptions.add(
      _shell.systemState.onDiagnosticsChanged.listen((_) {
        _updateDiagnosticText();
      }),
    );

    // Listen to notification history for message count.
    final nm = _shell.notifications;
    if (nm is DefaultNotificationManager) {
      void onHistoryChanged() => _updateNotificationText();
      nm.history.addListener(onHistoryChanged);
      _notificationHistoryListener = onHistoryChanged;
      _updateNotificationText();
    }
  }

  void _updateCursorListener() {
    // Remove previous listener.
    if (_cursorPositionListener != null) {
      _cursorPositionListener!();
      _cursorPositionListener = null;
    }

    final editor = _shell.systemState.activeEditor;
    if (editor is ForgeTextEditor) {
      void listener() {
        final pos = editor.cursorPosition.value;
        _cursorText.value = 'Ln ${pos.line + 1}, Col ${pos.column + 1}';
      }

      editor.cursorPosition.addListener(listener);
      _cursorPositionListener = () {
        editor.cursorPosition.removeListener(listener);
      };
      // Immediately sync current position.
      listener();
    } else {
      _cursorText.value = 'Ln 1, Col 1';
    }
  }

  void _updateLanguageText() {
    final editor = _shell.systemState.activeEditor;
    if (editor == null) {
      _languageText.value = 'Plain Text';
      return;
    }
    final ext = editor.uri.path.split('.').last.toLowerCase();
    _languageText.value = switch (ext) {
      'dart' => 'Dart',
      'md' || 'markdown' => 'Markdown',
      'yaml' || 'yml' => 'YAML',
      'json' => 'JSON',
      _ => 'Plain Text',
    };
  }

  void _updateDiagnosticText() {
    final all = _shell.diagnostics.all;
    final errors = all.where((d) => d.severity == ForgeSeverity.error).length;
    final warnings =
        all.where((d) => d.severity == ForgeSeverity.warning).length;
    _diagnosticText.value = '$errors errors, $warnings warnings';
  }

  void _updateNotificationText() {
    final nm = _shell.notifications;
    if (nm is DefaultNotificationManager) {
      final count = nm.history.value.length;
      _notificationText.value =
          count == 1 ? '1 message' : '$count messages';
    }
  }

  // ── Diagnostics & Output demo ──

  void _setupDiagnosticsAndOutput() {
    // Create a named diagnostic collection for the test module.
    _diagnosticCollection = _shell.diagnostics.createCollection('test-ide');

    // Create a build output channel for logging.
    _buildChannel = _shell.output.create('Build');
    _buildChannel!.appendLine('[Test IDE] Module activated');

    if (enableSampleDiagnostics) {
      // Optional demo diagnostics for showcase runs.
      _produceSampleDiagnostics();
    } else {
      _buildChannel?.appendLine('[Test IDE] Sample diagnostics disabled');
    }
  }

  void _produceSampleDiagnostics() {
    final collection = _diagnosticCollection;
    if (collection == null) return;

    final sampleUri = Uri.parse('file:///workspace/src/main.dart');
    final readmeUri = Uri.parse('file:///workspace/README.md');

    collection.set(sampleUri, [
      ForgeDiagnostic(
        uri: sampleUri,
        range: ForgeTextRange(
          start: const ForgeTextPosition(line: 4, column: 8),
          end: const ForgeTextPosition(line: 4, column: 20),
        ),
        message: "Undefined name 'undeclaredVar'",
        severity: ForgeSeverity.error,
        source: 'dart-analyzer',
        code: 'undefined_identifier',
      ),
      ForgeDiagnostic(
        uri: sampleUri,
        range: ForgeTextRange(
          start: const ForgeTextPosition(line: 12, column: 3),
          end: const ForgeTextPosition(line: 12, column: 10),
        ),
        message: "Unused import 'dart:io'",
        severity: ForgeSeverity.warning,
        source: 'dart-analyzer',
        code: 'unused_import',
      ),
      ForgeDiagnostic(
        uri: sampleUri,
        range: ForgeTextRange(
          start: const ForgeTextPosition(line: 25, column: 0),
          end: const ForgeTextPosition(line: 25, column: 40),
        ),
        message: 'Consider using a const constructor',
        severity: ForgeSeverity.hint,
        source: 'dart-analyzer',
        code: 'prefer_const_constructors',
      ),
    ]);

    collection.set(readmeUri, [
      ForgeDiagnostic(
        uri: readmeUri,
        range: ForgeTextRange(
          start: const ForgeTextPosition(line: 7, column: 0),
          end: const ForgeTextPosition(line: 7, column: 50),
        ),
        message: 'Broken link: ./docs/api.md not found',
        severity: ForgeSeverity.warning,
        source: 'markdown-lint',
      ),
      ForgeDiagnostic(
        uri: readmeUri,
        range: ForgeTextRange(
          start: const ForgeTextPosition(line: 15, column: 0),
          end: const ForgeTextPosition(line: 15, column: 30),
        ),
        message: 'Missing alt text for image',
        severity: ForgeSeverity.info,
        source: 'markdown-lint',
      ),
    ]);

    // Log the same issues to the build output channel.
    _buildChannel?.appendLine(
        '[Build] 1 error, 2 warnings, 1 info, 1 hint across 2 files');
    _buildChannel?.appendLine(
        '[Build] src/main.dart:5:9: error: Undefined name \'undeclaredVar\'');
    _buildChannel?.appendLine(
        '[Build] src/main.dart:13:4: warning: Unused import \'dart:io\'');
    _buildChannel?.appendLine(
        '[Build] README.md:8:1: warning: Broken link: ./docs/api.md');
  }

  // ── Default terminal ──

  void _createDefaultTerminal() {
    // Create a Terminal Log output channel so terminal output is mirrored
    // to the Output panel, demonstrating process+output integration.
    final terminalLog = _shell.output.create('Terminal Log');
    terminalLog.appendLine('[Terminal] Session started');
    _shell.terminals.create(
      name: 'bash',
      shellPath: '/bin/bash',
      outputChannel: terminalLog,
    );
  }

  // ── File error helpers ──

  void _emitFileErrorDiagnostic(Uri uri, String code, String message) {
    final collection = _diagnosticCollection;
    if (collection == null) return;
    collection.set(uri, [
      ForgeDiagnostic(
        uri: uri,
        range: const ForgeTextRange.empty(),
        message: message,
        severity: ForgeSeverity.error,
        source: 'file-system',
        code: code,
      ),
    ]);
    _buildChannel?.appendLine('[Error] $code: $message');
  }

  // ── Provider registration (Row 8) ──

  void _registerProviders() {
    // Outline provider for Dart files.
    _outlineProvider = DartOutlineProvider();
    final outlineMgr = _shell.outline;
    if (outlineMgr is DefaultOutlineManager) {
      _outlineRegistration = outlineMgr.registerProvider(_outlineProvider!);
    }

    // File decoration provider for modified (dirty) files.
    _decorationProvider = ModifiedFileDecorationProvider(
      systemState: _shell.systemState,
    );
    final decoMgr = _shell.fileDecorations;
    if (decoMgr is DefaultFileDecorationManager) {
      _decorationRegistration = decoMgr.registerProvider(_decorationProvider!);
    }

    _buildChannel?.appendLine('[Test IDE] Providers registered: outline, file-decorations');
  }

  // ── Module-scoped persistence (Row 10) ──

  void _restoreModuleState() {
    final store = _shell.storage.forModule(this);
    final lastPanel = store.get('lastActivePanel');
    if (lastPanel != null) {
      _buildChannel?.appendLine('[Test IDE] Restored last active panel: $lastPanel');
    }
    final activationCount = (store.get('activationCount') as int?) ?? 0;
    store.set('activationCount', activationCount + 1);
    _buildChannel?.appendLine('[Test IDE] Activation #${activationCount + 1}');
  }

  void _saveModuleState() {
    try {
      final store = _shell.storage.forModule(this);
      final active = _shell.systemState.activeEditor;
      if (active != null) {
        store.set('lastActivePanel', active.uri.toString());
      }
    } catch (_) {
      // Storage may be unavailable during teardown — ignore.
    }
  }

  // ── Cross-module registry (Row 11) ──

  void _logShellModuleCapabilities() {
    try {
      final shellModule = _shell.modules.get<TomForgeShellModule>();
      _buildChannel?.appendLine(
        '[Test IDE] Shell module "${shellModule.displayName}" supports '
        'extensions: ${TomForgeShellModule.supportedExtensions.join(", ")}',
      );
    } catch (_) {
      // Shell module not registered — skip.
    }
  }
}
