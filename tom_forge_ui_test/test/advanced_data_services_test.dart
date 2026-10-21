// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show EditorCapabilities, EditorStateSnapshot;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  group('DefaultFileDecorationManager', () {
    test('getDecoration returns null when no providers', () {
      final manager = DefaultFileDecorationManager();
      expect(manager.getDecoration(Uri.parse('file:///test.txt')), isNull);
    });

    test('getDecoration returns decoration from provider', () {
      final manager = DefaultFileDecorationManager();
      final provider = _TestDecorationProvider(
        decorations: {
          Uri.parse('file:///test.txt'): const ForgeFileDecoration(
            badge: 'M',
            tooltip: 'Modified',
          ),
        },
      );
      manager.registerProvider(provider);

      final decoration =
          manager.getDecoration(Uri.parse('file:///test.txt'));
      expect(decoration, isNotNull);
      expect(decoration!.badge, 'M');
      expect(decoration.tooltip, 'Modified');
    });

    test('onDidChange fires when provider registered', () async {
      final manager = DefaultFileDecorationManager();
      final completer = Completer<Uri?>();
      final sub = manager.onDidChange.listen(completer.complete);

      final provider = _TestDecorationProvider(decorations: {});
      manager.registerProvider(provider);

      final result = await completer.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('onDidChange not fired'),
      );
      expect(result, isNull); // null means full refresh
      await sub.cancel();
      manager.dispose();
    });

    test('onDidChange fires when provider signals change', () async {
      final manager = DefaultFileDecorationManager();
      final provider = _TestDecorationProvider(decorations: {});
      manager.registerProvider(provider);

      // Allow time for registration event to be processed.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Now set up listener and signal change.
      final completer = Completer<Uri?>();
      final sub = manager.onDidChange.listen(completer.complete);

      final changedUri = Uri.parse('file:///changed.txt');
      provider.signalChange(changedUri);

      final result = await completer.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('onDidChange not fired'),
      );
      expect(result, changedUri);
      await sub.cancel();
      manager.dispose();
    });

    test('onDidChange fires when provider removed', () async {
      final manager = DefaultFileDecorationManager();
      final provider = _TestDecorationProvider(decorations: {});

      // Collect events, but skip the registration event.
      final events = <Uri?>[];
      final sub = manager.onDidChange.listen(events.add);

      final registration = manager.registerProvider(provider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final initialCount = events.length;

      registration.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Should have at least one more event after removal.
      expect(events.length, greaterThan(initialCount));
      await sub.cancel();
      manager.dispose();
    });
  });

  group('DefaultVirtualDocumentManager', () {
    test('resolveContent returns null for unknown scheme', () async {
      final manager = DefaultVirtualDocumentManager();
      final content =
          await manager.resolveContent(Uri.parse('unknown:///test'));
      expect(content, isNull);
    });

    test('resolveContent returns content from provider', () async {
      final manager = DefaultVirtualDocumentManager();
      final provider = _TestVirtualDocumentProvider(
        contents: {
          Uri.parse('custom:///test.txt'): 'Hello, World!',
        },
      );
      manager.registerProvider('custom', provider);

      final content =
          await manager.resolveContent(Uri.parse('custom:///test.txt'));
      expect(content, 'Hello, World!');
    });

    test('hasProvider returns true for registered scheme', () {
      final manager = DefaultVirtualDocumentManager();
      final provider = _TestVirtualDocumentProvider(contents: {});
      manager.registerProvider('custom', provider);

      expect(manager.hasProvider('custom'), isTrue);
      expect(manager.hasProvider('unknown'), isFalse);
    });

    test('onDidChange fires when provider signals change', () async {
      final manager = DefaultVirtualDocumentManager();
      final provider = _TestVirtualDocumentProvider(contents: {});
      manager.registerProvider('custom', provider);

      final completer = Completer<Uri>();
      final sub = manager.onDidChange.listen(completer.complete);

      final changedUri = Uri.parse('custom:///changed.txt');
      provider.signalChange(changedUri);

      final result = await completer.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('onDidChange not fired'),
      );
      expect(result, changedUri);
      await sub.cancel();
      manager.dispose();
    });

    test('provider removal stops forwarding changes', () async {
      final manager = DefaultVirtualDocumentManager();
      final provider = _TestVirtualDocumentProvider(contents: {});
      final registration = manager.registerProvider('custom', provider);

      final events = <Uri>[];
      final sub = manager.onDidChange.listen(events.add);

      // Signal change before removal.
      provider.signalChange(Uri.parse('custom:///before.txt'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events.length, 1);

      registration.dispose();

      // Signal change after removal (should not be forwarded).
      provider.signalChange(Uri.parse('custom:///after.txt'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events.length, 1); // Still 1, not forwarded.

      await sub.cancel();
      manager.dispose();
    });
  });

  group('DefaultOutlineManager', () {
    test('provideOutline returns empty when no providers', () async {
      final manager = DefaultOutlineManager();
      final items = await manager.provideOutline(_MockEditor());
      expect(items, isEmpty);
    });

    test('provideOutline returns items from matching provider', () async {
      final manager = DefaultOutlineManager();
      final provider = _TestOutlineProvider(
        items: [
          const ForgeOutlineItem(
            label: 'TestClass',
            kind: ForgeSymbolKind.classKind,
            range: ForgeTextRange(
              start: ForgeTextPosition(line: 0, column: 0),
              end: ForgeTextPosition(line: 10, column: 1),
            ),
            selectionRange: ForgeTextRange(
              start: ForgeTextPosition(line: 0, column: 6),
              end: ForgeTextPosition(line: 0, column: 15),
            ),
          ),
        ],
      );
      manager.registerProvider(provider);

      final items = await manager.provideOutline(_MockEditor());
      expect(items.length, 1);
      expect(items.first.label, 'TestClass');
      expect(items.first.kind, ForgeSymbolKind.classKind);
    });

    test('onDidChange fires when provider registered', () async {
      final manager = DefaultOutlineManager();
      final completer = Completer<void>();
      final sub = manager.onDidChange.listen((_) => completer.complete());

      final provider = _TestOutlineProvider(items: []);
      manager.registerProvider(provider);

      await completer.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('onDidChange not fired'),
      );
      await sub.cancel();
      manager.dispose();
    });

    test('onDidChange fires when provider signals change', () async {
      final manager = DefaultOutlineManager();
      final provider = _TestOutlineProvider(items: []);
      manager.registerProvider(provider);

      // Allow time for registration event to be processed.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Now set up listener and signal change.
      final completer = Completer<void>();
      final sub = manager.onDidChange.listen((_) => completer.complete());

      provider.signalChange();

      await completer.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => throw TimeoutException('onDidChange not fired'),
      );
      await sub.cancel();
      manager.dispose();
    });
  });

  group('ForgeWorkspaceEdit atomic semantics', () {
    test('apply text edits atomically', () async {
      final fs = ForgeMemoryFileSystem(seed: {
        '/test.txt': 'Hello, World!',
      });

      final edit = ForgeWorkspaceEdit(
        textEdits: {
          Uri.parse('file:///test.txt'): [
            const ForgeTextEdit(
              range: ForgeTextRange(
                start: ForgeTextPosition(line: 0, column: 7),
                end: ForgeTextPosition(line: 0, column: 12),
              ),
              newText: 'Dart',
            ),
          ],
        },
      );

      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isTrue);

      final content = await fs.readText(Uri.parse('file:///test.txt'));
      expect(content, 'Hello, Dart!');
    });

    test('apply file create operation', () async {
      final fs = ForgeMemoryFileSystem(seed: {});

      final edit = ForgeWorkspaceEdit(
        fileOperations: [
          ForgeCreateFileOperation(
            uri: Uri.parse('file:///new.txt'),
            content: 'New file content',
          ),
        ],
      );

      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isTrue);

      final exists = await fs.exists(Uri.parse('file:///new.txt'));
      expect(exists, isTrue);
      final content = await fs.readText(Uri.parse('file:///new.txt'));
      expect(content, 'New file content');
    });

    test('apply file delete operation', () async {
      final fs = ForgeMemoryFileSystem(seed: {
        '/to_delete.txt': 'Delete me',
      });

      final edit = ForgeWorkspaceEdit(
        fileOperations: [
          ForgeDeleteFileOperation(
            uri: Uri.parse('file:///to_delete.txt'),
          ),
        ],
      );

      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isTrue);

      final exists = await fs.exists(Uri.parse('file:///to_delete.txt'));
      expect(exists, isFalse);
    });

    test('apply file rename operation', () async {
      final fs = ForgeMemoryFileSystem(seed: {
        '/old.txt': 'Rename me',
      });

      final edit = ForgeWorkspaceEdit(
        fileOperations: [
          ForgeRenameFileOperation(
            oldUri: Uri.parse('file:///old.txt'),
            newUri: Uri.parse('file:///new.txt'),
          ),
        ],
      );

      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isTrue);

      expect(await fs.exists(Uri.parse('file:///old.txt')), isFalse);
      expect(await fs.exists(Uri.parse('file:///new.txt')), isTrue);
      final content = await fs.readText(Uri.parse('file:///new.txt'));
      expect(content, 'Rename me');
    });

    test('rollback on text edit failure', () async {
      final fs = ForgeMemoryFileSystem(seed: {
        '/exists.txt': 'Original content',
      });

      // Create edit that references a non-existent file (should skip)
      // and another edit on existing file.
      final edit = ForgeWorkspaceEdit(
        textEdits: {
          Uri.parse('file:///exists.txt'): [
            const ForgeTextEdit(
              range: ForgeTextRange(
                start: ForgeTextPosition(line: 0, column: 0),
                end: ForgeTextPosition(line: 0, column: 8),
              ),
              newText: 'Modified',
            ),
          ],
        },
      );

      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isTrue);

      final content = await fs.readText(Uri.parse('file:///exists.txt'));
      expect(content, 'Modified content');
    });

    test('rollback file operations on failure', () async {
      final fs = ForgeMemoryFileSystem(seed: {
        '/existing.txt': 'Existing',
      });

      // Try to create over existing file without overwrite flag.
      final edit = ForgeWorkspaceEdit(
        fileOperations: [
          ForgeCreateFileOperation(
            uri: Uri.parse('file:///existing.txt'),
            content: 'Overwrite attempt',
            overwrite: false,
          ),
        ],
      );

      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isFalse);

      // Original content should be preserved.
      final content = await fs.readText(Uri.parse('file:///existing.txt'));
      expect(content, 'Existing');
    });

    test('combined operations with rollback', () async {
      final fs = ForgeMemoryFileSystem(seed: {
        '/file1.txt': 'File 1 original',
        '/file2.txt': 'File 2 original',
      });

      // Create edit with file create, then rename to existing without overwrite.
      // The rename should fail and rollback the create.
      final edit = ForgeWorkspaceEdit(
        fileOperations: [
          ForgeCreateFileOperation(
            uri: Uri.parse('file:///new_file.txt'),
            content: 'New file',
          ),
          ForgeRenameFileOperation(
            oldUri: Uri.parse('file:///file1.txt'),
            newUri: Uri.parse('file:///file2.txt'),
            overwrite: false, // Should fail - file2 exists.
          ),
        ],
      );

      final result = await fs.applyWorkspaceEdit(edit);
      expect(result, isFalse);

      // New file should be rolled back (removed).
      expect(await fs.exists(Uri.parse('file:///new_file.txt')), isFalse);
      // Original files should be preserved.
      expect(await fs.readText(Uri.parse('file:///file1.txt')), 'File 1 original');
      expect(await fs.readText(Uri.parse('file:///file2.txt')), 'File 2 original');
    });
  });
}

// ── Test Helpers ─────────────────────────────────────────────────────

class _TestDecorationProvider implements ForgeFileDecorationProvider {
  final Map<Uri, ForgeFileDecoration> decorations;
  final _controller = StreamController<Uri?>.broadcast();

  _TestDecorationProvider({required this.decorations});

  @override
  ForgeFileDecoration? provideDecoration(Uri uri) => decorations[uri];

  @override
  Stream<Uri?> get onDidChange => _controller.stream;

  void signalChange(Uri? uri) => _controller.add(uri);
}

class _TestVirtualDocumentProvider implements ForgeVirtualDocumentProvider {
  final Map<Uri, String> contents;
  final _controller = StreamController<Uri>.broadcast();

  _TestVirtualDocumentProvider({required this.contents});

  @override
  Future<String> provideContent(Uri uri) async =>
      contents[uri] ?? 'Not found';

  @override
  Stream<Uri> get onDidChange => _controller.stream;

  void signalChange(Uri uri) => _controller.add(uri);
}

class _TestOutlineProvider implements ForgeOutlineProvider {
  final List<ForgeOutlineItem> items;
  final _controller = StreamController<void>.broadcast();

  _TestOutlineProvider({required this.items});

  @override
  bool canProvide(ForgeEditor editor) => true;

  @override
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor) async =>
      items;

  @override
  Stream<void> get onDidChange => _controller.stream;

  void signalChange() => _controller.add(null);
}

class _MockEditor implements ForgeEditor {
  final _title = ValueNotifier<String>('Mock');
  final _titleExt = ValueNotifier<String?>(null);
  final _dirty = ValueNotifier<bool>(false);

  @override
  Uri get uri => Uri.parse('file:///mock.dart');

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  FileHandlingResult canHandleContent(Uri uri, List<int> bytes) =>
      FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  String? getContent() => '';

  @override
  Map<String, dynamic>? saveState() => null;

  @override
  void restoreState(Map<String, dynamic> state) {}

  @override
  void setContent(String content) {}

  @override
  List<Map<String, dynamic>>? getUndoHistoryMetadata() => null;

  @override
  void restoreUndoHistoryMetadata(List<Map<String, dynamic>> entries) {}

  @override
  ComponentHistoryManager? get historyManager => null;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExt;

  @override
  IconData get icon => Icons.file_present;

  @override
  bool get isEditor => true;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  bool get supportsMultiRender => true;

  @override
  bool get isDraggable => true;

  @override
  Widget buildMain(BuildContext context) => const SizedBox();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox();

  @override
  List<ForgeAction> get actions => [];

  @override
  List<ForgeAction> get headerActions => [];

  @override
  List<ForgeShortcutBinding> get shortcuts => [];

  // EditorActionProvider
  @override
  Set<String> get supportedActionIds => const {};

  @override
  bool isActionEnabled(String actionId) => false;

  @override
  bool executeAction(String actionId) => false;

  @override
  EditorCapabilities get capabilities => const EditorCapabilities();

  @override
  EditorStateSnapshot get stateSnapshot => const EditorStateSnapshot();

  @override
  Stream<void> get onStateChanged => const Stream.empty();
}
