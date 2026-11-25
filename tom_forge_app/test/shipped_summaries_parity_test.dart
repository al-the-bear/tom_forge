/// The summary pair Tom Forge ships — `assets/summaries/sdk_summary.sum` and
/// `assets/summaries/dart-editor/packages.sum`, each with its stamp — is the
/// pair `tom_dart_editor_test` builds and checks (its `shipped_summaries_test`
/// SUM-1 and SUM-3), byte for byte
/// (`tom_dart_analysis/doc/package_summary_generation.md`). The library
/// package lives in tom_forge_modules, cloned at `tom_ai/forge_modules`; the
/// check skips when that clone is not reachable.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _sdk = 'assets/summaries/sdk_summary.sum';
const _packages = 'assets/summaries/dart-editor/packages.sum';

/// Every file of the pair the bundler writes: the two summaries and their
/// stamps.
const _pair = [_sdk, '$_sdk.stamp', _packages, '$_packages.stamp'];

/// `tom_dart_editor_test`, which builds the pair, beside this repository.
const _source = '../../tom_ai/forge_modules/tom_dart_editor_test';

void main() {
  test(
    'SUM-2: the app ships tom_dart_editor_test\'s pair, stamps included',
    () {
      if (!Directory(_source).existsSync()) {
        markTestSkipped('$_source not reachable — nothing to compare');
        return;
      }
      for (final file in _pair) {
        expect(
          File(file).readAsBytesSync(),
          File('$_source/$file').readAsBytesSync(),
          reason: '$file differs from $_source/$file: copy the pair',
        );
      }
    },
  );
}
