import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_style/dart_style.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show DefaultNotificationManager, ForgePanelLocation, ForgeSeverity;
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Production IDE module providing views, actions, shortcuts, and status bar items.
///
/// Promoted from TestAppModule in tom_forge_ui_test with identical behavior.
class ForgeAppModule extends ForgeModule {
  ForgeAppModule({required Uri workspaceRootUri})
    : _workspaceRootUri = workspaceRootUri;

  final Uri _workspaceRootUri;
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

  /// Guards [deactivate] against running twice — a module may be deactivated
  /// explicitly and then again when the shell disposes its registry, and the
  /// second run would dispose already-disposed notifiers.
  bool _deactivated = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  VoidCallback? _cursorPositionListener;
  VoidCallback? _notificationHistoryListener;
  DartOutlineProvider? _outlineProvider;
  ModifiedFileDecorationProvider? _decorationProvider;
  ForgeDisposable? _outlineRegistration;
  ForgeDisposable? _decorationRegistration;
  ForgeOutputChannel? _shellOutputChannel;
  ForgeOutputChannel? _moduleOutputChannel;
  final Map<String, ForgeOutputChannel> _editorChannels =
      <String, ForgeOutputChannel>{};

  @override
  String get displayName => 'Tom Forge';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    _setupOutputChannels();
    _buildViews();
    _buildActions();
    _buildShortcuts();
    _buildStatusBarItems();
    _listenToStateChanges();
    _registerProviders();
    _createDefaultTerminal();
    _restoreModuleState();
  }

  @override
  void deactivate() {
    if (_deactivated) return;
    _deactivated = true;
    _saveModuleState();
    if (_cursorPositionListener != null) {
      _cursorPositionListener!();
      _cursorPositionListener = null;
    }
    _outlineRegistration?.dispose();
    _outlineRegistration = null;
    _outlineProvider?.dispose();
    _outlineProvider = null;
    _decorationRegistration?.dispose();
    _decorationRegistration = null;
    _decorationProvider?.dispose();
    _decorationProvider = null;
    if (_notificationHistoryListener != null) {
      final nm = _shell.notifications;
      if (nm is DefaultNotificationManager) {
        nm.history.removeListener(_notificationHistoryListener!);
      }
      _notificationHistoryListener = null;
    }
    _notificationText.dispose();
    _moduleOutputChannel?.appendLine('[Tom Forge] Module deactivated');
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
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
      // Activated via Shift+Cmd+E (macOS) or Shift+Ctrl+E.
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
        workspaceRoot: _workspaceRootUri.toFilePath(),
      ),
      ForgeRevisionView(
        workspaceState: _shell.workspaceState,
        systemState: _shell.systemState as DefaultSystemState,
        layoutController: _shell.layout,
        shellApi: _shell is DefaultShellApi ? _shell as DefaultShellApi : null,
        onDidSave: _shell.fileSystem.onDidSave,
      ),
    ]);
  }

  // ── Actions ──

  /// The Edit menu's undo and redo, dispatched the way the keystroke is.
  ///
  /// With an editor active, the menu item runs that editor's own
  /// `forge.edit.undo` / `forge.edit.redo` through the shell's standard-action
  /// route — the one the keystroke and the action bar take. It used to call
  /// the shell's undo manager directly, which only reached editors that push
  /// shadow entries into it: with any other editor focused (a tree-mode YAML
  /// editor, a model-owning editor such as Webwork's), Edit > Undo reversed
  /// whatever another editor had last pushed, and the document on screen did
  /// not change. An active editor that does not offer the action leaves the
  /// menu item unavailable; only with no editor active does it fall back to
  /// the shell manager.
  void _historyAction(String actionId, Future<void> Function() shellFallback) {
    final editor = _shell.systemState.activeEditor;
    if (editor == null) {
      unawaited(shellFallback());
      return;
    }
    if (editor.supportedActionIds.contains(actionId)) {
      _shell.executeAction(actionId);
    }
  }

  bool _historyEnabled(String actionId, bool shellCan) {
    final editor = _shell.systemState.activeEditor;
    if (editor == null) return shellCan;
    return editor.supportedActionIds.contains(actionId) &&
        editor.isActionEnabled(actionId);
  }

  void _buildActions() {
    final fileSave = ForgeAction(
      id: 'file.save',
      label: 'Save',
      icon: Icons.save,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        final editor = _shell.systemState.activeEditor;
        if (editor != null && saveOwnedEditor(editor) == null) {
          final content = editor.getContent();
          if (content != null) {
            await _shell.fileSystem.writeText(editor.uri, content);
          }
          await _shell.fileSystem.save(editor.uri);
          editor.markClean();
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
        for (final editor in _shell.systemState.dirtyEditors.toList()) {
          if (saveOwnedEditor(editor) != null) continue;
          final content = editor.getContent();
          if (content != null) {
            await _shell.fileSystem.writeText(editor.uri, content);
          }
          await _shell.fileSystem.save(editor.uri);
          editor.markClean();
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
        _historyAction(
          StandardEditingActions.undoActionId,
          _shell.undoManager.undo,
        );
        return null;
      },
      isEnabled: () => _historyEnabled(
        StandardEditingActions.undoActionId,
        _shell.undoManager.canUndo.value,
      ),
      isVisible: () => true,
    );

    final editRedo = ForgeAction(
      id: 'edit.redo',
      label: 'Redo',
      icon: Icons.redo,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _historyAction(
          StandardEditingActions.redoActionId,
          _shell.undoManager.redo,
        );
        return null;
      },
      isEnabled: () => _historyEnabled(
        StandardEditingActions.redoActionId,
        _shell.undoManager.canRedo.value,
      ),
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
        _shell.notifications.showInformation('Tom Forge v1.0.0');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    final editToggleComment = ForgeAction(
      id: 'edit.toggleComment',
      label: 'Toggle Line Comment',
      icon: Icons.comment,
      menu: ForgeMenuLocation.edit,
      execute: (_) async {
        _shell.notifications.showInformation('Toggle Line Comment executed');
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
        _shell.notifications.showInformation('Toggle Block Comment executed');
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
        await _formatActiveDocument();
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    final toolsFormatDocument = ForgeAction(
      id: 'tools.formatDocument',
      label: 'Format Active Document',
      icon: Icons.auto_fix_high,
      menu: ForgeMenuLocation.tools,
      execute: (_) async {
        await _formatActiveDocument();
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
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
        // Delegate to the active editor's delete-line implementation.
        // Editor-level actions (e.g. dart.deleteLine) register themselves
        // in the shell action registry when the editor opens.
        if (!_shell.executeAction('dart.deleteLine')) {
          final editor = _shell.systemState.activeEditor;
          if (editor != null) {
            _shell.notifications.showInformation(
              'Delete line not available for ${editor.title}',
            );
          }
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    _actions.addAll([
      fileSave,
      fileSaveAll,
      fileClose,
      fileCloseAll,
      editUndo,
      editRedo,
      editFindInFiles,
      editorFind,
      editorDeleteLine,
      editToggleComment,
      editToggleBlockComment,
      editFormatDocument,
      toolsFormatDocument,
      viewToggleExplorer,
      viewToggleOutline,
      viewToggleProblems,
      viewToggleOutput,
      viewSplitEditor,
      helpAbout,
    ]);
  }

  // ── Shortcuts ──

  void _buildShortcuts() {
    // Shell-level shortcuts (forge.commandPalette, forge.toggleLeftPanel, etc.)
    // and standard editing shortcuts (forge.edit.undo, forge.edit.redo, etc.)
    // are provided by TomForgeShellModule.  This module only adds bindings
    // for app-level actions that are NOT already covered by the shell module.
    //
    // Note: Cmd+P, Cmd+L, Cmd+R, Cmd+B, Cmd+S, Cmd+F, Cmd+1-4, Cmd+]/[
    // are all provided by TomForgeShellModule.
    // Cmd+U (Undo), Cmd+Z (Redo) are provided by StandardEditingActions
    // descriptors via TomForgeShellModule.
    // Cmd+X/C/V are handled by Flutter's built-in text editing.
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
          _shell.notifications.showInformation(
            'Encoding: ${_encodingText.value}',
          );
        },
      ),
      StatusBarItem(
        text: _languageText,
        alignment: StatusBarAlignment.center,
        priority: 100,
        tooltip: 'Language Mode',
        isActive: (_) => _shell.systemState.activeEditor != null,
        onTap: () {
          _shell.notifications.showInformation(
            'Language: ${_languageText.value}',
          );
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
        _persistEditorContext();
        _logActiveEditor('Editors changed');
      }),
    );

    _subscriptions.add(
      _shell.systemState.onFocusChanged.listen((_) {
        _updateLanguageText();
        _updateCursorListener();
        _persistEditorContext();
        _logActiveEditor('Focus changed');
      }),
    );

    _subscriptions.add(
      _shell.systemState.onDiagnosticsChanged.listen((_) {
        _updateDiagnosticText();
        _shellOutputChannel?.appendLine(
          '[Diagnostics] $_diagnosticText',
        );
      }),
    );

    // Listen for notification history changes.
    final nm = _shell.notifications;
    if (nm is DefaultNotificationManager) {
      void onHistoryChanged() {
        _updateNotificationText(nm);
      }
      nm.history.addListener(onHistoryChanged);
      _notificationHistoryListener = onHistoryChanged;
    }
  }

  void _updateNotificationText(DefaultNotificationManager nm) {
    final count = nm.history.value.length;
    _notificationText.value = '$count message${count == 1 ? '' : 's'}';
  }

  void _updateLanguageText() {
    final active = _shell.systemState.activeEditor;
    if (active == null) {
      _languageText.value = 'Plain Text';
      return;
    }

    final ext = active.uri.path.split('.').lastOrNull ?? '';
    final language = switch (ext.toLowerCase()) {
      'dart' => 'Dart',
      'md' => 'Markdown',
      'yaml' || 'yml' => 'YAML',
      'json' => 'JSON',
      'txt' => 'Plain Text',
      _ => 'Plain Text',
    };
    _languageText.value = language;
  }

  void _updateDiagnosticText() {
    final all = _shell.diagnostics.all;
    final errors = all.where((d) => d.severity == ForgeSeverity.error).length;
    final warnings = all
        .where((d) => d.severity == ForgeSeverity.warning)
        .length;
    _diagnosticText.value = '$errors errors, $warnings warnings';
  }

  void _updateCursorListener() {
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
      listener();
    } else {
      _cursorText.value = 'Ln 1, Col 1';
    }
  }

  void _persistEditorContext() {
    try {
      final store = _shell.storage.forModule(this);
      final active = _shell.systemState.activeEditor;
      if (active != null) {
        unawaited(store.set('lastActiveEditorUri', active.uri.toString()));
        unawaited(store.set('lastActivePanel', active.uri.toString()));
      }
      unawaited(
        store.set(
          'lastActiveMiddlePanel',
          _shell.systemState.activeMiddlePanelIndex,
        ),
      );
      unawaited(store.set('lastKnownLanguage', _languageText.value));
    } catch (_) {
      // Storage may be unavailable during teardown — ignore.
    }
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
    _moduleOutputChannel?.appendLine(
      '[Tom Forge] Providers registered: outline + file decorations',
    );
  }

  void _setupOutputChannels() {
    _shellOutputChannel = _shell.output.create('Forge Shell');
    _moduleOutputChannel = _shell.output.create('Tom Forge Module');
    _editorChannels
      ..clear()
      ..addAll({
        'dart': _shell.output.create('Dart Editor'),
        'md': _shell.output.create('Markdown Editor'),
        'yaml': _shell.output.create('YAML Editor'),
        'txt': _shell.output.create('Text Editor'),
      });

    _shellOutputChannel?.appendLine('[Forge Shell] Runtime initialized');
    _moduleOutputChannel?.appendLine('[Tom Forge] Module activated');
  }

  void _createDefaultTerminal() {
    final terminalChannel = _shell.output.create('Terminal Log');
    terminalChannel.appendLine('[Terminal] Session started');
    final shellPath = _defaultShellPath();
    _shell.terminals.create(
      name: _defaultShellName(shellPath),
      shellPath: shellPath,
      cwd: _shell.systemState.workspaceRootPath,
      outputChannel: terminalChannel,
    );
  }

  String _defaultShellPath() {
    if (Platform.isWindows) {
      return Platform.environment['COMSPEC'] ?? 'cmd.exe';
    }
    final envShell = Platform.environment['SHELL'];
    if (envShell != null && envShell.isNotEmpty) return envShell;
    return Platform.isMacOS ? '/bin/zsh' : '/bin/bash';
  }

  String _defaultShellName(String shellPath) {
    final segment = shellPath.split(Platform.isWindows ? r'\' : '/').last;
    return segment.isEmpty ? 'shell' : segment;
  }

  void _logActiveEditor(String reason) {
    final active = _shell.systemState.activeEditor;
    if (active == null) {
      _shellOutputChannel?.appendLine('[Forge Shell] $reason: no active editor');
      return;
    }

    final ext = active.uri.path.split('.').last.toLowerCase();
    _shellOutputChannel?.appendLine(
      '[Forge Shell] $reason: ${active.uri.path}',
    );
    _editorChannels[ext]?.appendLine('[Editor] Active file: ${active.uri.path}');
  }

  // ── Module-scoped persistence (Row 10) ──

  void _restoreModuleState() {
    final store = _shell.storage.forModule(this);
    final activationCount = (store.get('activationCount') as int?) ?? 0;
    unawaited(store.set('activationCount', activationCount + 1));

    final lastLanguage = store.get<String>('lastKnownLanguage');
    if (lastLanguage != null && lastLanguage.isNotEmpty) {
      _languageText.value = lastLanguage;
    }

    final lastCursor = store.get<String>('lastCursorText');
    if (lastCursor != null && lastCursor.isNotEmpty) {
      _cursorText.value = lastCursor;
    }
  }

  void _saveModuleState() {
    try {
      final store = _shell.storage.forModule(this);
      final active = _shell.systemState.activeEditor;
      if (active != null) {
        unawaited(store.set('lastActiveEditorUri', active.uri.toString()));
        unawaited(store.set('lastActivePanel', active.uri.toString()));
      }
      unawaited(store.set('lastCursorText', _cursorText.value));
      unawaited(store.set('lastKnownLanguage', _languageText.value));
      unawaited(
        store.set(
          'lastActiveMiddlePanel',
          _shell.systemState.activeMiddlePanelIndex,
        ),
      );
    } catch (_) {
      // Storage may be unavailable during teardown — ignore.
    }
  }

  Future<void> _formatActiveDocument() async {
    final editor = _shell.systemState.activeEditor;
    if (editor is! ForgeTextEditor) {
      _shell.notifications.showWarning(
        'Formatting is only available for text editors.',
      );
      return;
    }

    final current = editor.getContent();
    if (current == null) {
      _shell.notifications.showWarning('No editable text content available.');
      return;
    }

    final formatted = _formatEditorContent(editor, current);
    if (formatted == current) {
      _shell.notifications.showInformation('Document is already formatted.');
      return;
    }

    final applied = _applyFormattedContent(editor, formatted);
    if (!applied) {
      _shell.notifications.showWarning(
        'Formatting is not supported for this editor type.',
      );
      return;
    }

    _shell.notifications.showInformation('Formatted ${editor.title.value}.');
  }

  String _formatEditorContent(ForgeEditor editor, String content) {
    if (editor is ForgeDartEditor) {
      try {
        return DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
        ).format(content);
      } catch (_) {
        // Fall through to whitespace formatting if Dart parsing fails.
      }
    }
    return _normalizeWhitespace(content);
  }

  bool _applyFormattedContent(ForgeEditor editor, String content) {
    if (editor is ForgeDartEditor) {
      editor.controller.userCode = content;
      return true;
    }
    if (editor is ForgeMdEditor) {
      editor.controller.markdown = content;
      return true;
    }
    if (editor is ForgePlainTextEditor) {
      editor.controller.markdown = content;
      return true;
    }
    if (editor is ForgeYamlEditor) {
      editor.controller.setYaml(content);
      return true;
    }
    return false;
  }

  String _normalizeWhitespace(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = const LineSplitter()
        .convert(normalized)
        .map((line) => line.replaceFirst(RegExp(r'\s+\n?$'), ''))
        .toList(growable: false);
    var result = lines.join('\n');
    if (normalized.endsWith('\n') && !result.endsWith('\n')) {
      result = '$result\n';
    }
    return result;
  }
}
