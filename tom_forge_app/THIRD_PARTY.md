# Third-party software

Tom Forge is licensed under the BSD 3-Clause License; the text is in
[`LICENSE`](LICENSE). That licence covers Tom Forge's own code, which is every
`tom_*` package this application links. This file lists the terms under which
the work of others that the application links is conveyed.

## What the application links

Every package the application links grants one of these licences:

- the BSD 3-Clause and 2-Clause licences, MIT, Apache-2.0, ISC or zlib —
  permissive terms, under which the work may be carried in a BSD-3 product
  as long as its notice travels with it;
- the Mozilla Public License 2.0, for the packages listed below — copyleft per
  file only, so the application around those files keeps its own terms.

No package under the GNU General Public License, the GNU Lesser General Public
License or the GNU Affero General Public License is linked. The LGPL in
particular is not admitted: an ahead-of-time Flutter build links statically
and cannot meet its relinking requirement.

A Flutter build collects the `LICENSE` text of every package it links into the
`NOTICES` asset of the application it produces, and the application shows it
in its licence page. That is where the notice of each permissive package
travels; this file does not repeat them.

The list below is checked by `test/qim_none1_licence_audit_test.dart`. The
test walks the packages this application resolves, through `dependencies:`
from `tom_forge_app` (development-only dependencies are not linked), reads
each package's `LICENSE`, and fails on a package that has none, one under a GPL
family, an MPL-2.0 package missing from the table below, or a row that names
no MPL-2.0 package the application links. Packages of the Flutter SDK are
judged by the SDK's own licence (BSD 3-Clause).

## MPL-2.0

These packages are distributed under the Mozilla Public License 2.0. Tom Forge
uses them unmodified; their source, the Covered Software, is available from
the locations given, and from pub.dev under the package's name.

| Package | Source | Reached through |
| --- | --- | --- |
| `dbus` | <https://github.com/canonical/dbus.dart>, by Canonical | `tom_forge_ui` → `file_picker` → `file_picker_linux` (the Linux file dialog over the desktop portal) |

## Vendored and shipped components

Native and web components that reach a user without being a Dart package:
vendored in a Tom package (its `third_party/` folders and the licence files of
its assets) or loaded from the binaries layer. The Dart audit above does not
see them; `test/qim_none1_vendored_components_test.dart` lists every vendored
component of the Tom packages this application links and fails when one has
no row here (its folder, `<package>/<folder>` in backticks, in the *Where* column; a component outside the Tom packages is named without backticks), when a row
names a folder that holds none, or when a licence file in it is outside the
admitted families: the permissive ones above, and for fonts and data the SIL
Open Font License 1.1 and CC0-1.0. The licence texts are beside each
component; each Tom package's own `THIRD_PARTY.md` describes what it vendors.
The vendored folders of pub.dev packages travel under the package's own
`LICENSE` and the `NOTICES` asset.

Programs the application starts as processes from the binaries layer (the
office editors' LibreOfficeKit helper `tom_office_host`, for one) are no
packages the application links. The same test checks them from
`tom_binaries/LICENSE`: every binary names its package, and every component
that package vendors has a row in the package's own `THIRD_PARTY.md` and an
admitted licence. For these, MPL-2.0 is admitted too (file-level copyleft
that a BSD-3 binary may carry), when the component says where its source is.

| Component | Where | Licence | How it reaches a user |
| --- | --- | --- | --- |
| PDFium — its public headers (pdfium-binaries `chromium/8152`) | `tom_pdf_editor/third_party/pdfium` | BSD-3-Clause | read at build time into the FFI bindings; not shipped as files |
| PDFium — the library `libpdfium.dylib` | the binaries layer (the tom_binaries repository, pdfium/*platform*/) | BSD-3-Clause, with permissive third-party code built in (FreeType, HarfBuzz, ICU, libjpeg-turbo, OpenJPEG, libpng, zlib, lcms2, abseil), one text each in its `licenses/` folder | loaded at runtime by the PDFium editor; not shipped inside the app |
| mermaid.js 11.13.0, the unmodified distribution build `mermaid.min.js` (its bundled dependencies in `tom_mermaid_view/THIRD_PARTY.md`) | `tom_mermaid_view/assets/js` | MIT; its bundled dependencies MIT, ISC (`d3`), BSD-3-Clause (`d3-sankey`), DOMPurify MPL-2.0 or Apache-2.0 (used under Apache-2.0) | shipped as a Flutter asset, loaded into the Markdown editor's Mermaid webview (`tom_md_editor` → `tom_mermaid_view`) |
| pdf.js 6.5.438 (Mozilla), the legacy viewer build and its viewer components | `tom_pdf_editor/third_party/pdfjs` | Apache-2.0; its data: OpenJPEG BSD-2-Clause, the JBIG2 decoder BSD-3-Clause, qcms and QuickJS MIT, the CMaps BSD-3-Clause (Adobe), the ICC profiles CC0-1.0, the Foxit fonts BSD-3-Clause, Liberation Sans 2.1.5 OFL-1.1 (in place of pdf.js's GPL copy) | shipped as Flutter assets, served to the pdf.js view's webview |
