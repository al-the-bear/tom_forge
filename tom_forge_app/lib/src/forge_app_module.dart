import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgePanelLocation, ForgeSeverity;
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
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  VoidCallback? _cursorPositionListener;
  DartOutlineProvider? _outlineProvider;
  ModifiedFileDecorationProvider? _decorationProvider;
  ForgeDisposable? _outlineRegistration;
  ForgeDisposable? _decorationRegistration;

  @override
  String get displayName => 'Tom Forge';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    _buildViews();
    _buildActions();
    _buildShortcuts();
    _buildStatusBarItems();
    _listenToStateChanges();
    _registerProviders();
    _restoreModuleState();
  }

  @override
  void deactivate() {
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
        _shell.notifications.showInformation('Format Document executed');
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
        final editor = _shell.systemState.activeEditor;
        if (editor != null) {
          _shell.notifications.showInformation('Delete line in ${editor.title}');
        }
        return null;
      },
      isEnabled: () => _shell.systemState.activeEditor != null,
      isVisible: () => true,
    );

    _actions.addAll([
      fileSave, fileSaveAll, fileClose, fileCloseAll,
      editUndo, editRedo, editFindInFiles, editorFind, editorDeleteLine,
      editToggleComment, editToggleBlockComment, editFormatDocument,
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

    // ── Concept §11.3 standard shortcuts ──
    // Only single-modifier (Cmd/Ctrl+key) bindings are pre-assigned.
    // All other actions are accessible via command palette or custom
    // shortcut menus (concept §11.4, implemented in a later step).
    _shortcuts.addAll([
      // Cmd+S → Save all dirty editors (concept §11.3).
      bind(byId['file.saveAll']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyS, primaryModifier: true)),
      // Cmd+F → Find in focused component (concept §11.3).
      bind(byId['editor.find']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyF, primaryModifier: true)),
      // Cmd+Y → Delete line in text editor (concept §11.3).
      bind(byId['editor.deleteLine']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyY, primaryModifier: true)),
      // Cmd+U → Undo (concept §11.3).
      bind(byId['edit.undo']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyU, primaryModifier: true)),
      // Cmd+Z → Redo (concept §11.3).
      bind(byId['edit.redo']!, ForgeShortcutKey(
          key: LogicalKeyboardKey.keyZ, primaryModifier: true)),
    ]);

    // Note: Cmd+P, Cmd+L, Cmd+R, Cmd+1-4, Cmd+]/[ are registered in
    // ForgeShellScaffold as shell-level shortcuts (concept §11.3).
    // Cmd+X/C/V are handled by Flutter's built-in text editing.

    // Note: The following actions have NO pre-assigned shortcut per concept
    // §11.2-11.3 and are accessible via command palette or future custom
    // shortcut menus (concept §11.4):
    //   file.save, file.close, file.closeAll, edit.findInFiles,
    //   edit.toggleComment, edit.toggleBlockComment, edit.formatDocument,
    //   view.toggleExplorer, view.toggleOutline, view.toggleProblems,
    //   view.toggleOutput, view.splitEditor, help.about
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
          _shell.notifications.showInformation('Language: ${_languageText.value}');
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
          _shell.layout.togglePanel(ForgePanelLocation.bottom);
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
      }),
    );

    _subscriptions.add(
      _shell.systemState.onFocusChanged.listen((_) {
        _updateLanguageText();
        _updateCursorListener();
        _persistEditorContext();
      }),
    );

    _subscriptions.add(
      _shell.systemState.onDiagnosticsChanged.listen((_) {
        _updateDiagnosticText();
      }),
    );
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
    final warnings = all.where((d) => d.severity == ForgeSeverity.warning).length;
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
}
