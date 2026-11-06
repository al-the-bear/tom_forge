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
