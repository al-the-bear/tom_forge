# tom_forge_app

Main Tom Forge shell application.

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
