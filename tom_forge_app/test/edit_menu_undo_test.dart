/// The Edit menu's undo and redo reach the editor the user is looking at.
///
/// They used to call the shell's undo manager directly, which only reaches
/// editors that push shadow entries into it. With any other editor focused,
/// Edit > Undo reversed whatever another editor had last pushed. These tests
/// drive the **menu action**, since the keystroke route was never the broken
/// one.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_app/src/forge_app_module.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// An editor with its own history that pushes nothing into the shell's
/// manager — a tree-mode YAML editor, a model-owning editor.
class _OwnHistoryEditor extends ForgeTestTextEditor {
  _OwnHistoryEditor(super.module, {this.offersUndo = true});

  final bool offersUndo;
  final ran = <String>[];

  @override
  Set<String> get supportedActionIds => offersUndo
      ? const {
          StandardEditingActions.undoActionId,
          StandardEditingActions.redoActionId,
        }
      : const {};

  @override
  bool isActionEnabled(String actionId) =>
      supportedActionIds.contains(actionId);

  @override
  bool executeAction(String actionId) {
    ran.add(actionId);
    return true;
  }
}

void main() {
  late DefaultShellApi shell;
  late ForgeAction undo, redo;
  late List<String> foreign;

  setUp(() {
    shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'forge',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final module = ForgeAppModule(workspaceRootUri: Uri.parse('file:///'));
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
    final registry = shell.actionRegistry as DefaultActionRegistry;
    undo = registry.getAction('edit.undo')!;
    redo = registry.getAction('edit.redo')!;

    // Another editor's shadow entry, sitting in the shell's manager.
    foreign = [];
    (shell.undoManager as DefaultUndoManager).push(
      UndoEntry(
        undo: () async => foreign.add('undo'),
        redo: () async => foreign.add('redo'),
        label: 'an edit in some other editor',
      ),
    );
  });

  Future<void> run(ForgeAction action) async {
    await action.execute(const {});
    await Future<void>.delayed(Duration.zero);
  }

  test('with an editor that keeps its own history, Edit > Undo and Redo reach '
      'that editor and nothing else', () async {
    final editor = _OwnHistoryEditor(ForgeTestModule());
    shell.layout.openEditor(editor, editor.uri);

    expect(undo.isEnabled(), isTrue);
    await run(undo);
    await run(redo);
    expect(editor.ran, [
      StandardEditingActions.undoActionId,
      StandardEditingActions.redoActionId,
    ]);
    expect(
      foreign,
      isEmpty,
      reason: 'the edit the user cannot see is left alone',
    );
  });

  test('with an editor that offers no undo, the menu item is unavailable and '
      'does nothing', () async {
    final editor = _OwnHistoryEditor(ForgeTestModule(), offersUndo: false);
    shell.layout.openEditor(editor, editor.uri);

    expect(undo.isEnabled(), isFalse);
    expect(redo.isEnabled(), isFalse);
    await run(undo);
    expect(editor.ran, isEmpty);
    expect(foreign, isEmpty);
  });

  test(
    'with no editor active, the menu falls back to the shell manager',
    () async {
      expect(shell.systemState.activeEditor, isNull);
      expect(undo.isEnabled(), isTrue);
      await run(undo);
      expect(foreign, ['undo']);
    },
  );
}
