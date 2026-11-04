# tom_forge_app

Main Tom Forge shell application.

## Tom Forge as a library

`package:tom_forge_app/forge_suite.dart` composes Tom Forge with all of its
functionality, so an app built on Forge starts from it instead of copying
Forge's setup:

- `composeForgeSuite(shell:, workspaceRoot:, extensions:)` registers Forge's
  modules (the shell module, `ForgeAppModule`, `WebsiteEditorModule`), adds the
  tom_forge application (`forgeApplicationId`), then each
  `ForgeSuiteExtension`'s modules (activated and registered after Forge's) and
  applications (added after the tom_forge one), and restores the applications
  open at the last exit.
- `resolveForgeWorkspace(folder)` resolves a picked folder to its workspace
  root and state.
- `ForgeSuiteLauncher(appName:, extensions:)` is the root widget: the welcome
  page, then the shell over the picked folder.

`main.dart` is `runApp(const ForgeSuiteLauncher())`. Webforge passes its
extensions (the Webwork full-screen application, the quest extension). The
library names no Webwork package: Forge's licence direction holds.

## Website module layout

`composeForgeSuite` registers `WebsiteEditorModule` on every launch and places its four
views (the module exposes each individually for host placement, rather than the
host parsing `module.views` by title):

| View | Panel placement |
| --- | --- |
| `controlView` (Control) | left panel → **Website** tab |
| `contentView` (Content) | left panel → **Website** tab |
| `structureView` (Structure) | left panel → **Website** tab |
| `previewView` (Preview) | bottom panel → **Web Preview** tab |

The `website_editor_wiring_test.dart` guards this contract (all four views are
exposed and activation is safe without a `tom.website-editor.yaml`).

## Run

```bash
flutter pub get
flutter run --debug
```

## Linux WebView Rendering Notes

- The local Linux `flutter_inappwebview` fork now defaults to software rendering.
- The shell should render Mermaid/WebView content without manually setting `FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL`.
- To intentionally force hardware mode for diagnostics:

```bash
FLUTTER_INAPPWEBVIEW_LINUX_FORCE_GL=1 flutter run --debug
```

## Diagnostics

To verify selected rendering path:

```bash
flutter run --debug 2>&1 | grep -E "software rendering|hardware rendering|CustomPlatformView: using (pixel buffer|GL texture)"
```
