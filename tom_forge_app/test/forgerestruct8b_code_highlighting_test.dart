// Tom Forge highlights code blocks in every highlight.js language: its main
// calls useForgeCodeHighlighting (tom_highlight_js), and the editors ask
// tom_text_highlight's highlighterForLanguage.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_app/forge_suite.dart';
import 'package:tom_highlight_js/tom_highlight_js.dart';
import 'package:tom_text_highlight/tom_text_highlight.dart';

void main() {
  tearDown(unregisterHighlightJsLanguages);

  test('FCH-1: useForgeCodeHighlighting makes the highlight.js languages '
      'answer; the own highlighters stay first', () {
    expect(highlighterForLanguage('python'), isNull);
    useForgeCodeHighlighting();
    expect(highlighterForLanguage('python'), isA<HighlightJsHighlighter>());
    expect(highlighterForLanguage('sql'), isA<HighlightJsHighlighter>());
    expect(highlighterForLanguage('yaml'), isA<YamlHighlighter>());
    final tokens = (highlighterForLanguage('python')! as HighlightJsHighlighter)
        .tokenize('def f(): return 1');
    expect(tokens.map((t) => t.type), contains('keyword'));
  });
}
