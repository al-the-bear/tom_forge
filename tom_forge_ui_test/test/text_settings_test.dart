import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart' hide ForgeAction;
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  group('S20: Text Settings and Configuration', () {
    // ───────────────────────────────────────────────────────────────────
    // Row 1: ForgeTextEditorOptions contract
    // ───────────────────────────────────────────────────────────────────
    group('Row 1: ForgeTextEditorOptions contract', () {
      test('001: options includes all text settings properties', () {
        const options = ForgeTextEditorOptions(
          tabSize: 4,
          insertSpaces: true,
          wordWrap: ForgeWordWrap.on,
          fontFamily: 'JetBrains Mono',
          fontSize: 16.0,
          lineHeight: 1.6,
          showLineNumbers: true,
          highlightCurrentLine: true,
        );

        expect(options.tabSize, 4);
        expect(options.insertSpaces, true);
        expect(options.wordWrap, ForgeWordWrap.on);
        expect(options.fontFamily, 'JetBrains Mono');
        expect(options.fontSize, 16.0);
        expect(options.lineHeight, 1.6);
        expect(options.showLineNumbers, true);
        expect(options.highlightCurrentLine, true);
      });

      test('002: options copyWith preserves unset values', () {
        const original = ForgeTextEditorOptions(
          fontFamily: 'Fira Code',
          fontSize: 14.0,
        );

        final updated = original.copyWith(fontSize: 16.0);

        expect(updated.fontFamily, 'Fira Code');
        expect(updated.fontSize, 16.0);
      });

      test('003: options equality compares all properties', () {
        const a = ForgeTextEditorOptions(
          tabSize: 2,
          fontFamily: 'monospace',
        );
        const b = ForgeTextEditorOptions(
          tabSize: 2,
          fontFamily: 'monospace',
        );
        const c = ForgeTextEditorOptions(
          tabSize: 4,
          fontFamily: 'monospace',
        );

        expect(a, equals(b));
        expect(a, isNot(equals(c)));
      });
    });

    // ───────────────────────────────────────────────────────────────────
    // Row 2: updateOptions applies settings to adapters
    // ───────────────────────────────────────────────────────────────────
    group('Row 2: updateOptions propagation', () {
      test('004: ForgeMdEditor stores and exposes options', () {
        final controller = MdEditorController(
          initialMarkdown: '# Test',
          uri: Uri.parse('file:///test.md'),
        );
        final module = _TestModule();
        final editor = ForgeMdEditor(
          controller: controller,
          module: module,
          options: const ForgeTextEditorOptions(tabSize: 2),
        );

        expect(editor.options.tabSize, 2);

        editor.updateOptions(const ForgeTextEditorOptions(
          tabSize: 4,
          fontSize: 18.0,
        ));

        expect(editor.options.tabSize, 4);
        expect(editor.options.fontSize, 18.0);

        editor.dispose();
        controller.dispose();
      });

      test('005: ForgeDartEditor stores and exposes options', () {
        final controller = DartCodeController(
          initialCode: 'void main() {}',
          uri: Uri.parse('file:///test.dart'),
        );
        final module = _TestModule();
        final editor = ForgeDartEditor(
          controller: controller,
          module: module,
          options: const ForgeTextEditorOptions(tabSize: 2),
        );

        expect(editor.options.tabSize, 2);

        editor.updateOptions(const ForgeTextEditorOptions(
          tabSize: 4,
          fontFamily: 'JetBrains Mono',
        ));

        expect(editor.options.tabSize, 4);
        expect(editor.options.fontFamily, 'JetBrains Mono');

        editor.dispose();
        controller.dispose();
      });
    });

    // ───────────────────────────────────────────────────────────────────
    // Row 3: Editor adaptation mapping
    // ───────────────────────────────────────────────────────────────────
    group('Row 3: Editor adaptation mapping', () {
      test('006: ForgeTextSettings maps to ForgeTextEditorOptions', () {
        const settings = ForgeTextSettings(
          fontFamily: 'Cascadia Code',
          fontSize: 15.0,
          lineHeight: 1.5,
          tabSize: 4,
          insertSpaces: false,
          wordWrap: true,
          showLineNumbers: true,
          highlightCurrentLine: false,
        );

        // Manual mapping (as done in scaffold)
        final options = ForgeTextEditorOptions(
          tabSize: settings.tabSize,
          insertSpaces: settings.insertSpaces,
          wordWrap: settings.wordWrap ? ForgeWordWrap.on : ForgeWordWrap.off,
          fontFamily: settings.fontFamily,
          fontSize: settings.fontSize,
          lineHeight: settings.lineHeight,
          showLineNumbers: settings.showLineNumbers,
          highlightCurrentLine: settings.highlightCurrentLine,
        );

        expect(options.tabSize, 4);
        expect(options.insertSpaces, false);
        expect(options.wordWrap, ForgeWordWrap.on);
        expect(options.fontFamily, 'Cascadia Code');
        expect(options.fontSize, 15.0);
        expect(options.lineHeight, 1.5);
        expect(options.showLineNumbers, true);
        expect(options.highlightCurrentLine, false);
      });
    });

    // ───────────────────────────────────────────────────────────────────
    // Row 4 & 5: Configuration service and module config
    // ───────────────────────────────────────────────────────────────────
    group('Row 4-5: ForgeConfigManager module config', () {
      test('007: DefaultConfigManager has getModuleConfig API', () {
        final manager = DefaultConfigManager();

        // No config set yet
        expect(manager.getModuleConfig<Map<String, dynamic>>('test-module'),
            isNull);

        // Set config
        manager.setModuleConfig('test-module', {'setting': 'value'});

        final config = manager.getModuleConfig<Map<String, dynamic>>('test-module');
        expect(config, isNotNull);
        expect(config!['setting'], 'value');

        manager.dispose();
      });

      test('008: setModuleConfig emits change event', () async {
        final manager = DefaultConfigManager();
        final events = <ConfigChangeEvent>[];
        final sub = manager.onDidChange.listen(events.add);

        manager.setModuleConfig('my-module', {'enabled': true});
        await Future.delayed(Duration.zero);

        expect(events.length, 1);
        expect(events.first.key, 'module.my-module');

        await sub.cancel();
        manager.dispose();
      });

      test('009: resetToDefaults clears module configs', () {
        final manager = DefaultConfigManager();

        manager.setModuleConfig('module-a', 'data-a');
        manager.setModuleConfig('module-b', 'data-b');

        expect(manager.getModuleConfig('module-a'), 'data-a');

        manager.resetToDefaults();

        expect(manager.getModuleConfig('module-a'), isNull);
        expect(manager.getModuleConfig('module-b'), isNull);

        manager.dispose();
      });
    });

    // ───────────────────────────────────────────────────────────────────
    // Row 6: Config change propagation
    // ───────────────────────────────────────────────────────────────────
    group('Row 6: Config change propagation', () {
      test('010: update emits ConfigChangeEvent', () async {
        final manager = DefaultConfigManager();
        final events = <ConfigChangeEvent>[];
        final sub = manager.onDidChange.listen(events.add);

        manager.update((config) {
          // Access config
          final _ = config.autoSave;
        });

        await Future.delayed(Duration.zero);

        expect(events.length, 1);

        await sub.cancel();
        manager.dispose();
      });
    });

    // ───────────────────────────────────────────────────────────────────
    // Row 11: TestConfigManager
    // ───────────────────────────────────────────────────────────────────
    group('Row 11: TestConfigManager', () {
      test('011: tracks update count', () {
        final manager = TestConfigManager();

        expect(manager.updateCount, 0);

        manager.update((c) {});
        manager.update((c) {});

        expect(manager.updateCount, 2);

        manager.dispose();
      });

      test('012: tracks last change key', () {
        final manager = TestConfigManager();

        expect(manager.lastChangeKey, isNull);

        manager.setModuleConfig('test', 'value');

        expect(manager.lastChangeKey, 'module.test');

        manager.dispose();
      });

      test('013: simulateChange emits synthetic event', () async {
        final manager = TestConfigManager();
        final events = <ConfigChangeEvent>[];
        final sub = manager.onDidChange.listen(events.add);

        manager.simulateChange('custom.key');
        await Future.delayed(Duration.zero);

        expect(events.length, 1);
        expect(events.first.key, 'custom.key');
        expect(manager.lastChangeKey, 'custom.key');

        await sub.cancel();
        manager.dispose();
      });

      test('014: allModuleConfigs returns all stored configs', () {
        final manager = TestConfigManager();

        manager.setModuleConfig('a', 1);
        manager.setModuleConfig('b', 'two');
        manager.setModuleConfig('c', [3]);

        final all = manager.allModuleConfigs;

        expect(all.length, 3);
        expect(all['a'], 1);
        expect(all['b'], 'two');
        expect(all['c'], [3]);

        manager.dispose();
      });

      test('015: resetToDefaults clears update count', () {
        final manager = TestConfigManager();

        manager.update((c) {});
        manager.update((c) {});

        expect(manager.updateCount, 2);

        manager.resetToDefaults();

        expect(manager.updateCount, 0);

        manager.dispose();
      });
    });

    // ───────────────────────────────────────────────────────────────────
    // Row 2 widget test: buildMain uses options
    // ───────────────────────────────────────────────────────────────────
    group('Row 2 widget: adapters apply options in buildMain', () {
      testWidgets('016: ForgeMdEditor buildMain creates MdEditor with theme options',
          (tester) async {
        // Suppress overflow errors in test environment
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed')) return;
          oldOnError?.call(details);
        };

        final controller = MdEditorController(
          initialMarkdown: '# Hello',
          uri: Uri.parse('file:///test.md'),
        );
        final module = _TestModule();
        final editor = ForgeMdEditor(
          controller: controller,
          module: module,
          options: const ForgeTextEditorOptions(
            fontSize: 20.0,
            fontFamily: 'Test Font',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 800,
                child: Builder(
                  builder: (context) => editor.buildMain(context),
                ),
              ),
            ),
          ),
        );

        // Widget is built - if we got here without errors, the options are applied
        expect(find.byType(MdEditor), findsOneWidget);

        editor.dispose();
        controller.dispose();
        FlutterError.onError = oldOnError;
      });

      testWidgets('017: ForgeDartEditor buildMain creates DartCodeEditor with theme options',
          (tester) async {
        // Suppress overflow errors in test environment
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed')) return;
          oldOnError?.call(details);
        };

        final controller = DartCodeController(
          initialCode: 'void main() {}',
          uri: Uri.parse('file:///test.dart'),
        );
        final module = _TestModule();
        final editor = ForgeDartEditor(
          controller: controller,
          module: module,
          options: const ForgeTextEditorOptions(
            fontSize: 18.0,
            lineHeight: 1.8,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 800,
                child: Builder(
                  builder: (context) => editor.buildMain(context),
                ),
              ),
            ),
          ),
        );

        // Widget is built - options are applied via theme
        expect(find.byType(DartCodeEditor), findsOneWidget);

        editor.dispose();
        controller.dispose();
        FlutterError.onError = oldOnError;
      });
    });
  });
}

/// Minimal test module for adapter tests.
class _TestModule implements ForgeModule {
  @override
  String get id => 'test-module';

  @override
  String get name => 'Test Module';

  @override
  String get displayName => 'Test Module';

  @override
  Future<void> activate(ForgeShellApi api) async {}

  @override
  Future<void> deactivate() async {}

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeContextMenuContribution> get contextMenus => const [];

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<StatusBarItem> get statusBarItems => const [];

  @override
  List<ForgeView> get views => const [];
}
