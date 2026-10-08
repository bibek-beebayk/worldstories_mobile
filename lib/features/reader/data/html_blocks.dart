import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

const _containerTags = {'div', 'section', 'article', 'main', 'body', 'span'};

/// Splits a section's HTML into paragraph-level blocks (paragraphs,
/// headings, images, lists...), descending through wrapper elements such as
/// `<div>`s. Rendering each block as its own widget lets the reader lay out,
/// paint and paginate a long section piece by piece instead of as one huge
/// widget.
///
/// Loose top-level text and inline elements are grouped into a paragraph
/// so nothing is lost.
List<String> splitHtmlBlocks(String html) {
  final blocks = <String>[];
  final inline = StringBuffer();

  void flushInline() {
    final text = inline.toString();
    if (text.trim().isNotEmpty) blocks.add('<p>$text</p>');
    inline.clear();
  }

  void visit(List<dom.Node> nodes) {
    for (final node in nodes) {
      if (node is dom.Element) {
        final name = node.localName ?? '';
        final hasOwnText = node.nodes.any(
          (child) => child is dom.Text && child.text.trim().isNotEmpty,
        );
        if (_containerTags.contains(name) &&
            node.children.isNotEmpty &&
            !hasOwnText) {
          flushInline();
          visit(node.nodes);
        } else if (_isInline(name)) {
          inline.write(node.outerHtml);
        } else {
          flushInline();
          blocks.add(node.outerHtml);
        }
      } else if (node is dom.Text) {
        inline.write(node.text);
      }
    }
  }

  visit(html_parser.parseFragment(html).nodes);
  flushInline();
  return blocks;
}

bool _isInline(String tag) => const {
  'a',
  'abbr',
  'b',
  'bdi',
  'bdo',
  'cite',
  'code',
  'em',
  'i',
  'kbd',
  'mark',
  'q',
  's',
  'samp',
  'small',
  'strong',
  'sub',
  'sup',
  'time',
  'u',
  'var',
  'br',
  'wbr',
  'span',
  'font',
}.contains(tag);
