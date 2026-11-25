# tom_forge_app

Main Tom Forge shell application.

## Tom Forge as a library

`package:tom_forge_app/forge_suite.dart` composes Tom Forge with all of its
functionality, so an app built on Forge starts from it instead of copying
Forge's setup:

- `composeForgeSuite(shell:, workspaceRoot:, navigatorKey:, extensions:,
  dartSummaryAssets:)` registers Forge's modules (the shell module,
  `ForgeAppModule`, `WebsiteEditorModule`, `ForgeQuestsModule` — the quest
  applications, from `tom_forge_quests` — and the office and PDF editors'
  kit modules), adds the tom_forge application
  (`forgeApplicationId`), then each `ForgeSuiteExtension`'s modules (activated
  and registered after Forge's), the file editors module, the extensions'
  applications (added after the tom_forge one), and restores the applications
  open at the last exit. The suite carries
  `navigatorKey`, which an extension module raises its dialogs on.
- **The file editors.** `suite.fileEditorsModule` (`tom_forge_file_editors`)
  opens Markdown, YAML, todo files, `.env` and other text in the editor of
  their kind, each over a `ForgeFileSession` that keeps the file's bytes and
  saves it; the Markdown and YAML kinds are the adapters' file kinds the
  suite registers with it (`forgeSuiteFileKinds`). It is registered after the extensions' modules, so a module that
  opens its own files (a Webwork document) is asked first, and it leaves a
  file to another module's editor that takes it (`tom.website-editor.yaml`),
  Dart files to the shell's Dart editor and an extension the user gave a
  default editor to that editor. An extension replaces Forge's editor of a
  kind through `ForgeSuiteExtension.fileEditorBuilders`, keyed by the kind's
  id (Webforge's rich Markdown editor under `forgeMarkdownFileKind.id`), and offers another beside it for some files through
  `ForgeSuiteExtension.fileEditorAlternatives` — Open With lists both
  (Webforge's TomSpecs editor for spec documents).
- **The office editors**, one kit module per route.
  `suite.officeLokModule` (`ForgeOfficeLokModule`, `tom_forge_office_lok`)
  opens `.docx .xlsx .pptx .odt .ods .odp` and the older `.doc .xls .ppt
  .rtf` in the LibreOfficeKit editor (the default; the installed LibreOffice
  through `tom_office_host` from the binaries layer) and adds LibreOffice's
  row to *External Tools*; `suite.officeZetaOfficeModule`
  (`ForgeZetaOfficeModule`, `tom_forge_office_zetaoffice`) offers ZetaOffice
  in a webview under *Open With*, and the suite wires it into the
  LibreOfficeKit module as its alternative route
  (`ForgeOfficeAlternativeRoute`: the missing-LibreOffice panel's *Open with
  ZetaOffice*, and the file-type default when it names ZetaOffice). Both are
  registered after the quests module, LibreOfficeKit first, before the PDF
  editors and the extensions' modules; the file editors leave those files to
  them, and `.csv` stays theirs (the office editors are offered for it under
  *Open With*). `composeForgeSuite(officeLokModule:, officeZetaOfficeModule:)`
  takes other modules (a test's, whose detection starts no process).
- **The PDF editors**, one kit module per engine. `suite.pdfiumModule`
  (`ForgePdfiumModule`, `tom_forge_pdf_pdfium`) opens every `.pdf` in the
  PDFium editor (the default); `suite.pdfJsModule` (`ForgePdfJsModule`,
  `tom_forge_pdf_pdfjs`) offers pdf.js under *Open With*. Both are registered
  after the office editors, PDFium first, and before the extensions'
  modules, so an extension's PDF editor adds a choice rather than replacing
  the default, and the file editors leave PDFs to them. An app that takes
  `tom_forge_pdf_pdfium` alone has no webview and no pdf.js (R6).
- `resolveForgeWorkspace(folder)` resolves a picked folder to its workspace
  root and state.
- `ForgeSuiteLauncher(appName:, extensions:, workspace:, dartSummaryAssets:,
  onComposed:)` is the root widget: the welcome page — or straight away the
  folder `workspace` names — then the shell over the folder; `onComposed` is
  called with each composed suite.

**The Dart editor's summaries.** This package carries
`assets/summaries/sdk_summary.sum` and `assets/summaries/dart-editor/packages.sum`
(with their stamps), the pair tom_dart_editor_bundler builds in
`tom_dart_editor_test` and copied here. Tom Forge's own app reads
them under its own keys (`ForgeDartSummaryAssets.root`, the default); an app
built on the library reads them under this package's prefix, which Flutter
gives a dependency's assets, by passing `forgeSuiteDartSummaries`.

`main.dart` runs `ForgeSuiteLauncher` with what the command line asks for
(`ForgeLaunch.parse`): `--workspace=<folder>` opens that folder at once, every
other argument not starting with `-` is a file opened in it (with no folder,
the first file's folder is the workspace; the user's file-type defaults
choose their editors), `--trail=pdf` switches the PDF editors' debug trails
on (`[FP]`, `[FPJ]`, `[PE]`, `[PE:js]`) and `--trail=office` the office
editors' (`[FO]`, `[FZO]`, `[OE]`, `[ZO]`). Webforge passes its
extensions (the Webwork full-screen application, the quest extension) and
`forgeSuiteDartSummaries`. The library names no Webwork package: Forge's
licence direction holds.

## Licence

Tom Forge is BSD-3-Clause, and an app built on it can be distributed as
BSD-3 on its own: every package this app links is permissive, or MPL-2.0 with
the notice in [`THIRD_PARTY.md`](THIRD_PARTY.md); nothing under a GPL family,
the LGPL included. `test/qim_none1_licence_audit_test.dart` holds it — it
walks the packages this app resolves (`tom_test_support`'s licence audit) and
fails on a missing licence, a GPL-family one, an MPL-2.0 package the notice
does not list, or build tooling (`tom_build_base`, `dcli`, `ini`) in the
resolved graph. `test/qim_none1_vendored_components_test.dart` covers what
the Dart graph does not show: every `third_party/` folder and asset licence
file of the Tom packages this app links (PDFium's headers, pdf.js) needs a row
in `THIRD_PARTY.md` § Vendored and shipped components and licence files of
the permissive families, OFL-1.1 or CC0-1.0. A second group reads `tom_binaries/LICENSE`: every
binary the apps start as a process names its package, and each component
that package vendors has a row in its `THIRD_PARTY.md` (MPL-2.0 admitted
there with its source location: the LibreOfficeKit headers of
`tom_office_host`). Run `flutter pub get` first: the
package configuration is what both read.

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
flutter run --debug --dart-entrypoint-args --workspace=$HOME/notes
flutter run --debug --dart-entrypoint-args=--trail=pdf \
  --dart-entrypoint-args=$HOME/notes/report.pdf
flutter run --debug --dart-entrypoint-args=--trail=office \
  --dart-entrypoint-args=$HOME/notes/report.docx
```

The macOS build needs CocoaPods on the `PATH` (`/opt/homebrew/bin`).

**Native binaries in the release bundle.** An app started from the Finder sees
no shell variable, so a release carries the native parts of the office and PDF
editors in its bundle, where `tom_basics`' `TomNativeBinaries` looks first. The
Runner target's last build phase, *Bundle Native Binaries*
(`macos/scripts/bundle_native_binaries.sh`), copies them from the binaries
layer on every `flutter build macos --release` (and `--profile`):

- `Contents/MacOS/`: `tom_office_host` and its trampoline
  `libtom_office_host_lok.dylib`, from `tom_binaries/tom/darwin-arm64/`;
- `Contents/Frameworks/`: `libpdfium.dylib`, from
  `tom_binaries/pdfium/darwin-arm64/`;
- `Contents/Resources/`: `pdfium.version.json` and PDFium's licences
  (`licenses/pdfium/`: its `LICENSE` and `licenses/`), from the same folder.

The `tom_binaries` clone is `TOM_BINARIES_ROOT` (environment or build
setting), else the parent of `TOM_BINARY_PATH`, else the clone beside
`tom_forge` in the agent container (`../../../tom_binaries` from `macos/`). A
release or profile build fails, naming the missing files, when one of them is
not there. Debug builds skip the phase — `flutter run` finds the binaries
through `TOM_BINARY_PATH`, so a rebuilt helper is used without rebuilding the
app; `TOM_BUNDLE_NATIVE_BINARIES=YES` bundles them in a debug build too, `NO`
builds a release without them. Each binary is copied to a new file, signed ad
hoc (`codesign --force --sign -`) and renamed into place before Xcode signs
the app; overwriting a signed executable in place hangs later starts. The app
has no hardened runtime, so it loads the ad-hoc signed `libpdfium` and the
helper its trampoline without library validation. The release bundle is
169 MB with the binaries, 154 MB without them (`du -sh`; the helper 7.3 MB,
PDFium 7.2 MB, the trampoline 68 KB, PDFium's licences 172 KB). LibreOffice
itself is not bundled: the office editor finds it in `/Applications`.

**Not sandboxed.** The release build ships without the App Sandbox, like the
debug and profile builds (`macos/Runner/Release.entitlements`; TD-25 of the
office/PDF prototype). The native editors need what the sandbox blocks: the
office editor starts its helper process (`tom_office_host`), and LibreOffice
loads from `/Applications`; the PDF editor loads PDFium, from the binaries
layer when the app runs from `flutter run`; pdf.js and ZetaOffice are served
by a local HTTP server on `127.0.0.1`; and Forge edits the files of its
workspace tree, not only files picked in an open panel. Risk R-1 of the
prototype's working document lists every denial of a sandboxed build. Forge
is not distributed through the App Store, so the sandbox buys nothing it
needs. A build that ran sandboxed once keeps a container, and the `defaults`
tool then names the container's preferences; the unsandboxed app reads
`~/Library/Preferences/com.example.tomForgeApp.plist`.

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
