import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/reader/data/html_blocks.dart';

void main() {
  test('splits paragraphs out of wrapper divs', () {
    final blocks = splitHtmlBlocks(
      '<div class="chapter"><h2>Title</h2><div><p>One</p><p>Two</p></div>'
      '<img src="a.jpg"></div>',
    );
    expect(blocks, [
      '<h2>Title</h2>',
      '<p>One</p>',
      '<p>Two</p>',
      '<img src="a.jpg">',
    ]);
  });

  test('keeps a div with its own text whole', () {
    expect(splitHtmlBlocks('<div>Hello <b>world</b></div>'), [
      '<div>Hello <b>world</b></div>',
    ]);
  });

  test('wraps loose text and inline elements in a paragraph', () {
    expect(splitHtmlBlocks('Loose <em>text</em><p>Para</p>'), [
      '<p>Loose <em>text</em></p>',
      '<p>Para</p>',
    ]);
  });
}
