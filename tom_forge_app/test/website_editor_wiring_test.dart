// Default-startup wiring for the website editor module.
//
// main.dart registers a [WebsiteEditorModule] on every Forge launch and places
// its three views (Preview / Control / Content) into the default layout. This
// guards two facts that make that safe:
//   1. The module exposes its three views individually for host placement.
//   2. Activation in a workspace WITHOUT a tom.website-editor.yaml does not
//      throw — activate() runs load() unawaited, so a missing/unreadable config
//      must settle into an error issue, never an unhandled zone error.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

void main() {
  group('Website editor default-startup wiring', () {
    late DefaultShellApi shell;

    setUp(() {
      shell = DefaultShellApi.withDefaults(
        fileSystemSeed: const {},
        appName: 'Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );
      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);
    });

    tearDown(() => shell.dispose());

    test('exposes its three views for host layout placement', () {
      final module = WebsiteEditorModule();
      module.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(module);

      expect(module.previewView, isNotNull);
      expect(module.controlView, isNotNull);
      expect(module.contentView, isNotNull);
      expect(module.views, hasLength(3));
      expect(
        module.views.map((v) => v.title.value),
        containsAll(<String>['Preview', 'Control', 'Content']),
      );

      module.deactivate();
    });

    test('activates safely without a config file (no zone throw)', () async {
      final module = WebsiteEditorModule();
      module.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(module);

      // Let the unawaited load() kicked by activate() settle. If it threw, the
      // flutter_test zone would fail this test.
      await Future<void>.delayed(Duration.zero);

      // And the failure is surfaced as an issue, not a crash: the module stays
      // unloaded with at least one issue recorded.
      final loaded = await module.controller!.load();
      expect(loaded, isFalse);
      expect(module.controller!.isLoaded, isFalse);
      expect(module.controller!.issues, isNotEmpty);

      module.deactivate();
    });
  });
}
