import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeDocumentAdapter;

/// Minimal [ForgeModule] for testing.
class _TestModule extends ForgeModule {
  @override
  String get displayName => 'Test';

  @override
  List<ForgeEditor> get editors => [];

  @override
  List<ForgeView> get views => [];

  @override
  List<ForgeAction> get actions => [];

  @override
  List<ForgeShortcutBinding> get shortcuts => [];

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}
}

void main() {
  group('Section 19: Editor Base Contracts and Text Editing Core', () {
    // ─── Row 1 + Row 2: Two-phase resolution ─────────────────────

    group('Two-phase file resolution', () {
      test('01A: ForgeMdEditor.canHandle accepts .md files', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: '', uri: Uri.parse('file:///test.md'));
        final editor = ForgeMdEditor(controller: controller, module: module);

        expect(editor.canHandle(Uri.parse('file:///foo.md')), FileHandlingResult.accept);
        expect(editor.canHandle(Uri.parse('file:///bar.markdown')), FileHandlingResult.accept);
        expect(editor.canHandle(Uri.parse('file:///baz.dart')), FileHandlingResult.reject);
      });

      test('01B: ForgeDartEditor.canHandle accepts .dart files', () {
        final module = _TestModule();
        final controller = DartCodeController(initialCode: '', uri: Uri.parse('file:///test.dart'));
        final editor = ForgeDartEditor(controller: controller, module: module);

        expect(editor.canHandle(Uri.parse('file:///foo.dart')), FileHandlingResult.accept);
        expect(editor.canHandle(Uri.parse('file:///bar.md')), FileHandlingResult.reject);
      });

      test('01C: ForgeYamlEditor.canHandle returns inspect for YAML files', () {
        final module = _TestModule();
        final controller = YamlEditorController(initialYaml: '', uri: Uri.parse('file:///test.yaml'));
        final editor = ForgeYamlEditor(controller: controller, module: module);

        // Schema editor returns inspect to allow content inspection
        expect(editor.canHandle(Uri.parse('file:///foo.yaml')), FileHandlingResult.inspect);
        expect(editor.canHandle(Uri.parse('file:///bar.yml')), FileHandlingResult.inspect);
      });

      test('01D: ForgeYamlEditor.canHandleContent validates YAML', () {
        final module = _TestModule();
        final controller = YamlEditorController(initialYaml: '', uri: Uri.parse('file:///test.yaml'));
        final editor = ForgeYamlEditor(controller: controller, module: module);

        final yamlBytes = 'key: value\nlist:\n  - item1\n  - item2'.codeUnits;
        final result = editor.canHandleContent(Uri.parse('file:///data.yaml'), yamlBytes);
        expect(result, FileHandlingResult.accept);
      });
    });

    // ─── Row 3: ForgeTextEditor base (already implemented) ───────

    group('ForgeTextEditor base contract', () {
      test('02A: ForgeMdEditor exposes document', () {
        final module = _TestModule();
        final controller = MdEditorController(
          initialMarkdown: 'Hello world',
          uri: Uri.parse('file:///test.md'),
        );
        final editor = ForgeMdEditor(controller: controller, module: module);

        expect(editor.document, isNotNull);
        expect(editor.document.text, 'Hello world');
        expect(editor.document.languageId, 'markdown');
      });

      test('02B: ForgeDartEditor exposes document', () {
        final module = _TestModule();
        final controller = DartCodeController(
          initialCode: 'void main() {}',
          uri: Uri.parse('file:///test.dart'),
        );
        final editor = ForgeDartEditor(controller: controller, module: module);

        expect(editor.document, isNotNull);
        expect(editor.document.text, 'void main() {}');
        expect(editor.document.languageId, 'dart');
      });

      test('02C: ForgeTextEditor.cursorPosition is observable', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'Line 1\nLine 2');
        final editor = ForgeMdEditor(controller: controller, module: module);

        expect(editor.cursorPosition, isA<ValueListenable<ForgeTextPosition>>());
        expect(editor.cursorPosition.value, const ForgeTextPosition.zero());
      });
    });

    // ─── Row 4: Multi-selection ──────────────────────────────────

    group('Multi-selection support', () {
      test('03A: setSelections stores all ranges in ValueNotifier', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'ABC DEF GHI');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final ranges = [
          const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 0),
            end: ForgeTextPosition(line: 0, column: 3),
          ),
          const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 4),
            end: ForgeTextPosition(line: 0, column: 7),
          ),
        ];

        editor.setSelections(ranges);
        expect(editor.selections.value.length, 2);
        expect(editor.selections.value[0].start.column, 0);
        expect(editor.selections.value[1].start.column, 4);
      });

      test('03B: ForgeDartEditor.setSelections stores all ranges', () {
        final module = _TestModule();
        final controller = DartCodeController(initialCode: 'abc def ghi');
        final editor = ForgeDartEditor(controller: controller, module: module);

        final ranges = [
          const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 0),
            end: ForgeTextPosition(line: 0, column: 3),
          ),
          const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 8),
            end: ForgeTextPosition(line: 0, column: 11),
          ),
        ];

        editor.setSelections(ranges);
        expect(editor.selections.value.length, 2);
      });

      test('03C: setSelections with empty list clears selection', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'test');
        final editor = ForgeMdEditor(controller: controller, module: module);

        editor.setSelection(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 4),
        ));
        expect(editor.selection.value, isNotNull);

        editor.setSelections([]);
        expect(editor.selection.value, isNull);
        expect(editor.selections.value, isEmpty);
      });
    });

    // ─── Row 5: Visible range (already implemented) ──────────────

    group('Visible range reporting', () {
      test('04A: ForgeMdEditor.visibleRange is observable', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'Line 1\nLine 2');
        final editor = ForgeMdEditor(controller: controller, module: module);

        expect(editor.visibleRange, isA<ValueListenable<ForgeTextRange>>());
      });

      test('04B: ForgeDartEditor.visibleRange is observable', () {
        final module = _TestModule();
        final controller = DartCodeController(initialCode: 'void main() {}');
        final editor = ForgeDartEditor(controller: controller, module: module);

        expect(editor.visibleRange, isA<ValueListenable<ForgeTextRange>>());
      });
    });

    // ─── Row 6: Text mutations (already implemented) ─────────────

    group('Text mutation operations', () {
      test('05A: insertText inserts at cursor', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'Hello World');
        final editor = ForgeMdEditor(controller: controller, module: module);

        editor.setCursorPosition(const ForgeTextPosition(line: 0, column: 5));
        editor.insertText(',');
        expect(controller.markdown, 'Hello, World');
      });

      test('05B: replaceRange replaces text', () {
        final module = _TestModule();
        final controller = DartCodeController(initialCode: 'void main() {}');
        final editor = ForgeDartEditor(controller: controller, module: module);

        editor.replaceRange(
          const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 0),
            end: ForgeTextPosition(line: 0, column: 4),
          ),
          'int',
        );
        expect(controller.userCode, 'int main() {}');
      });

      test('05C: deleteRange removes text', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'Hello World');
        final editor = ForgeMdEditor(controller: controller, module: module);

        editor.deleteRange(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 5),
          end: ForgeTextPosition(line: 0, column: 11),
        ));
        expect(controller.markdown, 'Hello');
      });
    });

    // ─── Row 7: Cursor/selection control ─────────────────────────

    group('Cursor and selection control', () {
      test('06A: setSelection updates both selection and selections', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'Hello World');
        final editor = ForgeMdEditor(controller: controller, module: module);

        editor.setSelection(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 5),
        ));

        expect(editor.selection.value, isNotNull);
        expect(editor.selection.value!.start.column, 0);
        expect(editor.selection.value!.end.column, 5);
        expect(editor.selections.value.length, 1);
      });

      test('06B: selectAll selects entire document', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'Hello');
        final editor = ForgeMdEditor(controller: controller, module: module);

        editor.selectAll();

        final sel = editor.selection.value;
        expect(sel, isNotNull);
        expect(sel!.start.line, 0);
        expect(sel.start.column, 0);
        expect(sel.end.column, 5);
      });
    });

    // ─── Row 8: In-editor search (already implemented) ───────────

    group('In-editor search', () {
      test('07A: findAll locates pattern matches', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'foo bar foo baz foo');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final matches = editor.findAll(RegExp('foo'));
        expect(matches.length, 3);
        expect(matches[0].start.column, 0);
        expect(matches[1].start.column, 8);
        expect(matches[2].start.column, 16);
      });

      test('07B: replaceAll replaces all occurrences', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'foo bar foo');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final count = editor.replaceAll(RegExp('foo'), 'qux');
        expect(count, 2);
        expect(controller.markdown, 'qux bar qux');
      });
    });

    // ─── Row 9: Document contract ────────────────────────────────

    group('ForgeDocument contract wiring', () {
      test('08A: Document.onDidChange is wired via ForgeDocumentAdapter', () async {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'initial');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final changeEvents = <DocumentChangeEvent>[];
        final sub = editor.document.onDidChange.listen(changeEvents.add);

        // Mutate via controller to trigger _onContentChanged
        controller.markdown = 'modified';
        await Future<void>.delayed(Duration.zero);

        expect(changeEvents.length, 1);
        expect(changeEvents.first.document.text, 'modified');

        await sub.cancel();
      });

      test('08B: Document.version increments on change', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'v0');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final v0 = editor.document.version;
        controller.markdown = 'v1';
        final v1 = editor.document.version;

        expect(v1, greaterThan(v0));
      });

      test('08C: DartEditor document.onDidChange fires', () async {
        final module = _TestModule();
        final controller = DartCodeController(initialCode: 'void main() {}');
        final editor = ForgeDartEditor(controller: controller, module: module);

        final changeEvents = <DocumentChangeEvent>[];
        final sub = editor.document.onDidChange.listen(changeEvents.add);

        controller.userCode = 'void main() { print(1); }';
        await Future<void>.delayed(Duration.zero);

        expect(changeEvents.length, 1);
        await sub.cancel();
      });

      test('08D: Document instance is cached', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'test');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final doc1 = editor.document;
        final doc2 = editor.document;
        expect(identical(doc1, doc2), isTrue);
      });
    });

    // ─── Row 10: Text editor options (already implemented) ──────

    group('Text editor options', () {
      test('09A: updateOptions stores new options', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: '');
        final editor = ForgeMdEditor(controller: controller, module: module);

        const options = ForgeTextEditorOptions(tabSize: 4, insertSpaces: true);
        editor.updateOptions(options);

        expect(editor.options.tabSize, 4);
        expect(editor.options.insertSpaces, isTrue);
      });
    });

    // ─── Row 11: Bridge/integration path ─────────────────────────

    group('ForgeDocumentAdapter bridge', () {
      test('10A: MdEditor document extends ForgeDocumentAdapter', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'test');
        final editor = ForgeMdEditor(controller: controller, module: module);

        expect(editor.document, isA<ForgeDocumentAdapter>());
      });

      test('10B: DartEditor document extends ForgeDocumentAdapter', () {
        final module = _TestModule();
        final controller = DartCodeController(initialCode: 'test');
        final editor = ForgeDartEditor(controller: controller, module: module);

        expect(editor.document, isA<ForgeDocumentAdapter>());
      });

      test('10C: ForgeDocumentAdapter.isDirty tracks dirty state', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'initial');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final doc = editor.document as ForgeDocumentAdapter;
        expect(doc.isDirty.value, isFalse);

        controller.markdown = 'modified';
        expect(doc.isDirty.value, isTrue);
      });
    });

    // ─── Row 12: System-state integration ────────────────────────

    group('System-state integration', () {
      test('11A: onDirtyStateChanged emits when editor dirty state changes', () async {
        final state = DefaultSystemState();
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'initial');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final dirtyEvents = <DirtyStateEvent>[];
        final sub = state.onDirtyStateChanged.listen(dirtyEvents.add);

        state.addOpenEditor(editor);
        controller.markdown = 'modified';
        await Future<void>.delayed(Duration.zero);

        expect(dirtyEvents.length, greaterThanOrEqualTo(1));
        expect(dirtyEvents.last.editor, editor);
        expect(dirtyEvents.last.isDirty, isTrue);

        await sub.cancel();
        state.dispose();
      });

      test('11B: dirtyEditors list updates on dirty change', () {
        final state = DefaultSystemState();
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'initial');
        final editor = ForgeMdEditor(controller: controller, module: module);

        state.addOpenEditor(editor);
        expect(state.dirtyEditors, isEmpty);

        controller.markdown = 'modified';
        expect(state.dirtyEditors, contains(editor));

        state.dispose();
      });

      test('11C: onSelectionChanged emits when active editor selection changes', () async {
        final state = DefaultSystemState();
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'Hello World');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final selEvents = <SelectionChangeEvent>[];
        final sub = state.onSelectionChanged.listen(selEvents.add);

        state.addOpenEditor(editor);
        state.setActiveEditor(editor);

        editor.setSelection(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 5),
        ));
        await Future<void>.delayed(Duration.zero);

        expect(selEvents.length, greaterThanOrEqualTo(1));
        expect(selEvents.last.component, editor);

        await sub.cancel();
        state.dispose();
      });

      test('11D: onTextSelectionChanged emits with ForgeTextRange', () async {
        final state = DefaultSystemState();
        final module = _TestModule();
        final controller = DartCodeController(initialCode: 'void main() {}');
        final editor = ForgeDartEditor(controller: controller, module: module);

        final textSelEvents = <TextSelectionChangeEvent>[];
        final sub = state.onTextSelectionChanged.listen(textSelEvents.add);

        state.addOpenEditor(editor);
        state.setActiveEditor(editor);

        editor.setSelection(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 4),
        ));
        await Future<void>.delayed(Duration.zero);

        expect(textSelEvents.length, greaterThanOrEqualTo(1));
        expect(textSelEvents.last.selection, isNotNull);
        expect(textSelEvents.last.selection!.end.column, 4);

        await sub.cancel();
        state.dispose();
      });

      test('11E: removeOpenEditor cleans up dirty listener', () async {
        final state = DefaultSystemState();
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'test');
        final editor = ForgeMdEditor(controller: controller, module: module);

        final dirtyEvents = <DirtyStateEvent>[];
        final sub = state.onDirtyStateChanged.listen(dirtyEvents.add);

        state.addOpenEditor(editor);
        controller.markdown = 'first change';
        await Future<void>.delayed(Duration.zero);
        final countAfterFirst = dirtyEvents.length;

        state.removeOpenEditor(editor);

        // Changes after removal should not emit
        controller.markdown = 'second change';
        await Future<void>.delayed(Duration.zero);

        expect(dirtyEvents.length, countAfterFirst);

        await sub.cancel();
        state.dispose();
      });

      test('11F: selection listener is cleaned up on editor switch', () async {
        final state = DefaultSystemState();
        final module = _TestModule();
        final controller1 = MdEditorController(initialMarkdown: 'editor 1');
        final editor1 = ForgeMdEditor(controller: controller1, module: module);
        final controller2 = MdEditorController(initialMarkdown: 'editor 2');
        final editor2 = ForgeMdEditor(controller: controller2, module: module);

        final selEvents = <SelectionChangeEvent>[];
        final sub = state.onSelectionChanged.listen(selEvents.add);

        state.addOpenEditor(editor1);
        state.addOpenEditor(editor2);
        state.setActiveEditor(editor1);

        editor1.setSelection(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 3),
        ));
        await Future<void>.delayed(Duration.zero);
        final countAfterEditor1 = selEvents.length;

        state.setActiveEditor(editor2);

        // Selection change on editor1 (no longer active) should not emit
        editor1.setSelection(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 6),
        ));
        await Future<void>.delayed(Duration.zero);

        // Selection on editor2 (now active) should emit
        editor2.setSelection(const ForgeTextRange(
          start: ForgeTextPosition(line: 0, column: 0),
          end: ForgeTextPosition(line: 0, column: 2),
        ));
        await Future<void>.delayed(Duration.zero);

        // We should only see events from when editor1 was active and editor2 is now active
        expect(selEvents.where((e) => e.component == editor1).length, countAfterEditor1);
        expect(selEvents.where((e) => e.component == editor2).length, greaterThanOrEqualTo(1));

        await sub.cancel();
        state.dispose();
      });
    });

    // ─── Additional edge cases ───────────────────────────────────

    group('Edge cases', () {
      test('12A: Document URI returns controller URI for titled file', () {
        final module = _TestModule();
        final uri = Uri.parse('file:///path/to/test.md');
        final controller = MdEditorController(initialMarkdown: '', uri: uri);
        final editor = ForgeMdEditor(controller: controller, module: module);

        expect(editor.document.uri, uri);
        expect(editor.document.isUntitled, isFalse);
      });

      test('12B: Document isUntitled returns true for null URI', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: '');
        final editor = ForgeMdEditor(controller: controller, module: module);

        expect(editor.document.isUntitled, isTrue);
      });

      test('12C: dispose cleans up document resources', () {
        final module = _TestModule();
        final controller = MdEditorController(initialMarkdown: 'test');
        final editor = ForgeMdEditor(controller: controller, module: module);

        // Access document before dispose
        final doc = editor.document;
        expect(doc.text, 'test');

        // Should not throw
        editor.dispose();
      });
    });
  });
}
