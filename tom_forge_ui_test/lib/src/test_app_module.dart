import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation, ForgeSeverity;
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Test IDE module providing views, actions, shortcuts, and status bar items.
class TestAppModule extends ForgeModule {
  TestAppModule({required Uri workspaceRootUri})
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
  final List<StreamSubscription<dynamic>> _subscriptions = [];

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
  }

  @override
  void deactivate() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _cursorText.dispose();
    _encodingText.dispose();
    _languageText.dispose();
    _diagnosticText.dispose();
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

  // ── Views ──

  void _buildViews() {
    _views.addAll([
      ForgeFileExplorerView(
        fileSystem: _shell.fileSystem,
        layoutController: _shell.layout,
        rootUri: _workspaceRootUri,
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
          await _shell.fileSystem.save(editor.uri);
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
          await _shell.fileSystem.save(editor.uri);
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
        _shell.notifications.showInformation('Forge Test IDE v1.0.0');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );

    _actions.addAll([
      fileSave, fileSaveAll, fileClose, fileCloseAll,
      editUndo, editRedo, editFindInFiles,
      viewToggleExplorer, viewToggleOutline,
      viewToggleProblems, viewToggleOutput, viewSplitEditor,
      helpAbout,
    ]);
  }

  // ── Shortcuts ──

  void _buildShortcuts() {
    ForgeShortcutBinding bind(ForgeAction action, ForgeShortcutKey key) =>
        ForgeShortcutBinding(action: action, key: key);

    final byId = {for (final a in _actions) a.id: a};

    _shortcuts.addAll([
      bind(byId['file.save']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyS, primaryModifier: true)),
      bind(byId['file.saveAll']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyS, primaryModifier: true, shift: true)),
      bind(byId['file.close']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyW, primaryModifier: true)),
      bind(byId['file.closeAll']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyW, primaryModifier: true, shift: true)),
      bind(byId['edit.undo']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyZ, primaryModifier: true)),
      bind(byId['edit.redo']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyZ, primaryModifier: true, shift: true)),
      bind(byId['edit.findInFiles']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyF, primaryModifier: true, shift: true)),
      bind(byId['view.toggleExplorer']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyB, primaryModifier: true)),
      bind(byId['view.toggleOutline']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyO, primaryModifier: true, shift: true)),
      bind(byId['view.toggleProblems']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyM, primaryModifier: true, shift: true)),
      bind(byId['view.toggleOutput']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyU, primaryModifier: true, shift: true)),
      bind(byId['view.splitEditor']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.backslash, primaryModifier: true)),
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
      ),
      StatusBarItem(
        text: _encodingText,
        alignment: StatusBarAlignment.left,
        priority: 50,
        tooltip: 'File Encoding',
        isActive: (_) => true,
      ),
      StatusBarItem(
        text: _languageText,
        alignment: StatusBarAlignment.center,
        priority: 100,
        tooltip: 'Language Mode',
        isActive: (_) => _shell.systemState.activeEditor != null,
      ),
      StatusBarItem(
        text: _diagnosticText,
        icon: Icons.error_outline,
        alignment: StatusBarAlignment.right,
        priority: 100,
        tooltip: 'Problems',
        isActive: (_) => true,
      ),
    ]);
  }

  // ── State listeners ──

  void _listenToStateChanges() {
    _subscriptions.add(
      _shell.systemState.onEditorsChanged.listen((event) {
        _updateLanguageText();
      }),
    );

    _subscriptions.add(
      _shell.systemState.onDiagnosticsChanged.listen((_) {
        _updateDiagnosticText();
      }),
    );
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
}
