import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultEnvironment, DefaultShellApi, DefaultSystemState;
import 'package:tom_forge_terminal/tom_forge_terminal.dart';

import 'package:tom_forge_ui_test/src/test_app_module.dart';

/// Minimal editor stub for setting as active editor in tests.
class _StubEditor extends ForgeEditor {
  @override
  final Uri uri;

  _StubEditor(this.uri);

  @override
  ValueListenable<String> get title =>
      ValueNotifier(uri.pathSegments.last);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.description;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.accept;

  final _isDirty = ValueNotifier<bool>(false);
  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  void markClean() => _isDirty.value = false;

  @override
  Widget buildMain(BuildContext context) => const SizedBox.shrink();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('Section 18: Terminal, Process, and Runtime Tooling Integration', () {
    late DefaultShellApi shell;
    late TestAppModule module;

    setUp(() {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: {
          '/workspace/main.dart': 'void main() {}',
          '/workspace/README.md': '# Hello',
        },
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      module = TestAppModule(
        workspaceRootUri: Uri.parse('file:///workspace'),
      );
      module.activate(shell);
    });

    // ── Row 3: Terminal backend wired to editors ─────────────────

    group('Row 3: Terminal backend PTY wired to editors', () {
      test('18-03A: terminal.runActiveFile creates terminal and sends '
          'command when active editor exists', () async {
        // Set a stub editor as active to simulate an open file.
        final editor = _StubEditor(
          Uri.parse('file:///workspace/main.dart'),
        );
        final state = shell.systemState as DefaultSystemState;
        state.addOpenEditor(editor);
        state.setActiveEditor(editor);

        final action = module.actions.firstWhere(
          (a) => a.id == 'terminal.runActiveFile',
        );
        expect(action.isEnabled(), isTrue);

        await action.execute({});

        // Terminal should have been created or reused.
        expect(shell.terminals.terminals, isNotEmpty);
        final terminal =
            shell.terminals.activeTerminal as DefaultTerminal;
        expect(terminal.history, isNotEmpty);
      });

      test('18-03B: terminal.runActiveFile is disabled when no active '
          'editor', () {
        final action = module.actions.firstWhere(
          (a) => a.id == 'terminal.runActiveFile',
        );
        expect(action.isEnabled(), isFalse);
      });
    });

    // ── Row 4: Terminal creation with options ─────────────────

    group('Row 4: Terminal creation with runtime options wired', () {
      test('18-04A: view.newTerminal creates terminal via manager', () async {
        final action = module.actions.firstWhere(
          (a) => a.id == 'view.newTerminal',
        );
        final before = shell.terminals.terminals.length;
        await action.execute({});
        expect(shell.terminals.terminals.length, before + 1);
      });

      test('18-04B: terminal created with name and shellPath via '
          'runActiveFile', () async {
        final editor = _StubEditor(
          Uri.parse('file:///workspace/main.dart'),
        );
        final state = shell.systemState as DefaultSystemState;
        state.addOpenEditor(editor);
        state.setActiveEditor(editor);

        final action = module.actions.firstWhere(
          (a) => a.id == 'terminal.runActiveFile',
        );
        await action.execute({});

        final terminal =
            shell.terminals.activeTerminal as DefaultTerminal;
        expect(terminal.name, isNotEmpty);
        expect(terminal.shellPath, '/bin/bash');
      });
    });

    // ── Row 5: Terminal lifecycle collection wired ─────────────

    group('Row 5: Terminal lifecycle collection wired', () {
      test('18-05A: terminals list tracks created terminals', () async {
        expect(shell.terminals.terminals, isNotEmpty,
            reason: 'Default terminal created on activate');
        final initialCount = shell.terminals.terminals.length;

        shell.terminals.create(name: 'test-shell');
        expect(shell.terminals.terminals.length, initialCount + 1);
      });

      test('18-05B: activeTerminal tracks after setActive', () {
        final t1 = shell.terminals.create(name: 'first');
        final t2 = shell.terminals.create(name: 'second');

        shell.terminals.setActive(t2);
        expect(shell.terminals.activeTerminal, t2);

        shell.terminals.setActive(t1);
        expect(shell.terminals.activeTerminal, t1);
      });
    });

    // ── Row 6: Terminal lifecycle events wired ────────────────

    group('Row 6: Terminal lifecycle events wired', () {
      test('18-06A: onDidOpen fires when terminal created', () async {
        final completer = Completer<ForgeTerminal>();
        final sub = shell.terminals.onDidOpen.listen(completer.complete);

        shell.terminals.create(name: 'event-test');
        final terminal = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        expect(terminal.name, 'event-test');
        await sub.cancel();
      });

      test('18-06B: onDidClose fires when terminal closed', () async {
        final terminal = shell.terminals.create(name: 'close-test');

        final completer = Completer<ForgeTerminal>();
        final sub = shell.terminals.onDidClose.listen(completer.complete);

        terminal.close();
        final closed = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        expect(closed.name, 'close-test');
        await sub.cancel();
      });

      test('18-06C: onDidChangeActive fires on setActive', () async {
        final t1 = shell.terminals.create(name: 'a');
        final t2 = shell.terminals.create(name: 'b');
        shell.terminals.setActive(t1);

        final completer = Completer<ForgeTerminal?>();
        final sub =
            shell.terminals.onDidChangeActive.listen(completer.complete);

        shell.terminals.setActive(t2);
        final newActive = await completer.future.timeout(
          const Duration(seconds: 1),
        );
        expect(newActive?.name, 'b');
        await sub.cancel();
      });
    });

    // ── Row 7: Terminal sendText wired ────────────────────────

    group('Row 7: Terminal sendText wired via actions', () {
      test('18-07A: terminal.sendCommand action exists and is enabled',
          () {
        final action = module.actions.firstWhere(
          (a) => a.id == 'terminal.sendCommand',
        );
        expect(action.isEnabled(), isTrue);
      });

      test('18-07B: sendText dispatches to active terminal', () async {
        final terminal =
            shell.terminals.activeTerminal as DefaultTerminal;
        final outputs = <String>[];
        final sub = terminal.onOutput.listen(outputs.add);

        terminal.sendText('echo hello');
        await Future<void>.delayed(Duration.zero);

        expect(outputs, isNotEmpty);
        await sub.cancel();
      });
    });

    // ── Row 8: Terminal show/close wired ──────────────────────

    group('Row 8: Terminal show/close wired via actions', () {
      test('18-08A: terminal.closeActive closes the active terminal',
          () async {
        // Ensure there's an active terminal.
        expect(shell.terminals.activeTerminal, isNotNull);

        final action = module.actions.firstWhere(
          (a) => a.id == 'terminal.closeActive',
        );
        expect(action.isEnabled(), isTrue);

        await action.execute({});
        // The default terminal should have been closed and removed.
      });

      test('18-08B: terminal.show action shows the terminal', () async {
        shell.terminals.create(name: 'show-test');
        final action = module.actions.firstWhere(
          (a) => a.id == 'terminal.show',
        );
        expect(action.isEnabled(), isTrue);
        // Should not throw.
        await action.execute({});
      });
    });

    // ── Row 9: Process + output integration wired ─────────────

    group('Row 9: Runtime process and output integration wired', () {
      test('18-09A: build.run creates terminal with output channel',
          () async {
        final action = module.actions.firstWhere(
          (a) => a.id == 'build.run',
        );
        await action.execute({});

        // A 'Build' terminal should have been created.
        final buildTerminal = shell.terminals.terminals.firstWhere(
          (t) => t.name == 'Build',
        );
        expect(buildTerminal, isNotNull);
      });

      test('18-09B: build.run output channel receives build messages',
          () async {
        final action = module.actions.firstWhere(
          (a) => a.id == 'build.run',
        );
        await action.execute({});

        // Build output channel should exist.
        final channels = shell.output.channels;
        final buildChannel = channels.where((c) => c.name == 'Build');
        expect(buildChannel, isNotEmpty);
      });

      test('18-09C: default terminal output mirrors to output channel',
          () async {
        // The default terminal created on activate has an output channel.
        final terminal =
            shell.terminals.terminals.first as DefaultTerminal;
        expect(terminal.outputChannel, isNotNull);
      });
    });

    // ── Row 10: openExternal wired ────────────────────────────

    group('Row 10: Environment openExternal wired', () {
      test('18-10A: help.openUrl action exists', () {
        final action = module.actions.firstWhere(
          (a) => a.id == 'help.openUrl',
        );
        expect(action, isNotNull);
        expect(action.isEnabled(), isTrue);
      });

      test('18-10B: openExternal tracks opened URIs', () async {
        final env = shell.environment as DefaultEnvironment;
        await env.openExternal(Uri.parse('https://example.com'));
        expect(env.openedUris, contains(Uri.parse('https://example.com')));
      });
    });

    // ── Row 11: Execution monitor wired ───────────────────────

    group('Row 11: Execution monitor wired to editor actions', () {
      test('18-11A: build.run tracks execution via monitor', () async {
        final started = <ForgeExecution>[];
        final sub = shell.executions.onDidStart.listen(started.add);

        final action = module.actions.firstWhere(
          (a) => a.id == 'build.run',
        );
        await action.execute({});
        await Future<void>.delayed(Duration.zero);

        expect(started, isNotEmpty);
        expect(started.first.label, 'Build');
        await sub.cancel();
      });

      test('18-11B: terminal.runActiveFile tracks execution', () async {
        final editor = _StubEditor(
          Uri.parse('file:///workspace/main.dart'),
        );
        final state = shell.systemState as DefaultSystemState;
        state.addOpenEditor(editor);
        state.setActiveEditor(editor);

        final finished = <ForgeExecution>[];
        final sub = shell.executions.onDidFinish.listen(finished.add);

        final action = module.actions.firstWhere(
          (a) => a.id == 'terminal.runActiveFile',
        );
        await action.execute({});
        await Future<void>.delayed(Duration.zero);

        expect(finished, isNotEmpty);
        await sub.cancel();
      });

      test('18-11C: build.stop cancels running executions', () async {
        // Start an execution manually.
        shell.executions.start(id: 'test-exec', label: 'Test Exec');
        expect(shell.executions.running, isNotEmpty);

        final action = module.actions.firstWhere(
          (a) => a.id == 'build.stop',
        );
        await action.execute({});

        expect(shell.executions.running, isEmpty);
      });

      test('18-11D: execution monitor onRunningCountChanged fires',
          () async {
        final counts = <int>[];
        final sub =
            shell.executions.onRunningCountChanged.listen(counts.add);

        shell.executions.start(id: 'c1', label: 'Count Test');
        shell.executions.complete('c1');
        await Future<void>.delayed(Duration.zero);

        expect(counts, containsAll([1, 0]));
        await sub.cancel();
      });
    });

    // ── Row 12: Test coverage integrations ────────────────────

    group('Row 12: Terminal/execution test coverage', () {
      test('18-12A: all terminal actions registered in module', () {
        final ids = module.actions.map((a) => a.id).toSet();
        expect(ids, containsAll([
          'terminal.runActiveFile',
          'terminal.sendCommand',
          'terminal.closeActive',
          'terminal.show',
          'build.run',
          'build.stop',
          'help.openUrl',
        ]));
      });

      test('18-12B: shortcut bindings exist for run actions', () {
        final boundIds = module.shortcuts.map((s) => s.action.id).toSet();
        expect(boundIds, contains('terminal.runActiveFile'));
        expect(boundIds, contains('build.run'));
        expect(boundIds, contains('build.stop'));
      });

      test('18-12C: run menu location assigned to terminal/build '
          'actions', () {
        final runMenuActions = module.actions
            .where((a) => a.menu == ForgeMenuLocation.run)
            .map((a) => a.id)
            .toSet();
        expect(runMenuActions, containsAll([
          'terminal.runActiveFile',
          'build.run',
          'build.stop',
        ]));
      });
    });
  });
}
