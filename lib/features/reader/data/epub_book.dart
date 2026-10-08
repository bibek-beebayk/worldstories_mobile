import 'dart:typed_data';

import 'package:epub_view/epub_view.dart' as epub;
import 'package:html/parser.dart' as html_parser;

import 'html_blocks.dart';

/// One spine item (an XHTML file) of an EPUB, ready to render.
final class EpubSection {
  const EpubSection({
    required this.spineIndex,
    required this.idref,
    required this.href,
    required this.title,
    required this.bodyHtml,
    required this.textLength,
    required this.blockCount,
    this.blockPath = const [],
    this.blocks = const [],
  });

  /// Position in the package spine, used to build EPUB CFIs that the web
  /// reader (epub.js) understands.
  final int spineIndex;
  final String idref;

  /// Manifest href, relative to the package document.
  final String href;
  final String title;

  /// The file's `<body>` contents, with styles and scripts removed.
  final String bodyHtml;

  /// Plain-text length, used to weight overall progress by real length.
  final int textLength;

  /// Paragraph-level elements (the CFI's granularity): the body's children,
  /// or those of the lone wrapper element many books put everything in.
  final int blockCount;

  /// CFI steps from `<body>` down to the element whose children are the
  /// blocks (e.g. `[2]` for a single wrapping `<div>`).
  final List<int> blockPath;

  /// [bodyHtml] split into paragraph-level blocks for rendering (see
  /// [splitHtmlBlocks]). Done while parsing, off the UI thread.
  final List<String> blocks;
}

final class EpubTocEntry {
  const EpubTocEntry({
    required this.title,
    required this.sectionIndex,
    required this.depth,
  });

  final String title;
  final int sectionIndex;
  final int depth;
}

/// A parsed EPUB: its readable sections in spine order, the table of
/// contents mapped onto them, and its images.
final class EpubBookData {
  const EpubBookData({
    required this.title,
    required this.sections,
    required this.toc,
    required this.images,
  });

  final String title;
  final List<EpubSection> sections;
  final List<EpubTocEntry> toc;

  /// Image bytes by manifest href (relative to the package document).
  final Map<String, Uint8List> images;

  int get totalTextLength =>
      sections.fold(0, (sum, section) => sum + section.textLength);

  /// Whole-book progress from a position within one section, weighting each
  /// section by its text length (like epub.js locations on the web).
  double overallProgress(int sectionIndex, double sectionFraction) {
    final total = totalTextLength;
    if (total <= 0 || sections.isEmpty) {
      return sections.isEmpty
          ? 0
          : ((sectionIndex + sectionFraction) / sections.length).clamp(0, 1);
    }
    var before = 0;
    for (var i = 0; i < sectionIndex && i < sections.length; i++) {
      before += sections[i].textLength;
    }
    final current = sections[sectionIndex].textLength;
    return ((before + current * sectionFraction) / total).clamp(0.0, 1.0);
  }

  /// The inverse of [overallProgress], for restoring from a percentage.
  ({int section, double fraction}) positionForOverall(double overall) {
    final total = totalTextLength;
    if (sections.isEmpty) return (section: 0, fraction: 0);
    if (total <= 0) {
      final scaled = overall.clamp(0.0, 1.0) * sections.length;
      final index = scaled.floor().clamp(0, sections.length - 1);
      return (section: index, fraction: (scaled - index).clamp(0.0, 1.0));
    }
    var remaining = overall.clamp(0.0, 1.0) * total;
    for (var i = 0; i < sections.length; i++) {
      final length = sections[i].textLength;
      if (remaining <= length || i == sections.length - 1) {
        return (
          section: i,
          fraction: length <= 0 ? 0 : (remaining / length).clamp(0.0, 1.0),
        );
      }
      remaining -= length;
    }
    return (section: sections.length - 1, fraction: 1);
  }

  /// A CFI for [sectionIndex] at [fraction] of its body, e.g.
  /// `epubcfi(/6/8[chap03]!/4/12)`. Paragraph-level, which both this app and
  /// epub.js resolve.
  String cfiFor(int sectionIndex, double fraction) {
    final section = sections[sectionIndex];
    final spineStep = (section.spineIndex + 1) * 2;
    final idAssertion = section.idref.isEmpty ? '' : '[${section.idref}]';
    final block = section.blockCount <= 0
        ? 0
        : (fraction * section.blockCount).floor().clamp(
            0,
            section.blockCount - 1,
          );
    final path = [4, ...section.blockPath, (block + 1) * 2].join('/');
    return 'epubcfi(/6/$spineStep$idAssertion!/$path)';
  }

  /// Reads a CFI saved by this app, the previous app reader (epub_view) or
  /// the web reader (epub.js) back into a section and a position in it.
  ({int section, double fraction})? positionForCfi(String? cfi) {
    if (cfi == null) return null;
    final match = RegExp(
      r'epubcfi\(/6/(\d+)(?:\[[^\]]*\])?!?([^)]*)\)',
    ).firstMatch(cfi);
    if (match == null) return null;
    final spineIndex = int.parse(match.group(1)!) ~/ 2 - 1;
    final sectionIndex = sections.indexWhere(
      (section) => section.spineIndex == spineIndex,
    );
    if (sectionIndex < 0) return null;
    final steps = RegExp(r'/(\d+)')
        .allMatches(match.group(2) ?? '')
        .map((step) => int.parse(step.group(1)!))
        .toList();
    final section = sections[sectionIndex];
    var fraction = 0.0;
    // Steps are /4 (body), the path to the blocks' parent, then /N (the
    // Nth/2 block).
    final path = section.blockPath;
    final blockStep = 1 + path.length;
    final pathMatches = [
      for (var i = 0; i < path.length; i++)
        i + 1 < steps.length && steps[i + 1] == path[i],
    ].every((matches) => matches);
    if (steps.isNotEmpty &&
        steps.first == 4 &&
        pathMatches &&
        steps.length > blockStep &&
        section.blockCount > 0) {
      final block = steps[blockStep] ~/ 2 - 1;
      fraction = (block / section.blockCount).clamp(0.0, 1.0);
    }
    return (section: sectionIndex, fraction: fraction);
  }

  /// The section a link inside [fromSection] points to, if it's in the book.
  int? sectionForLink(int fromSection, String url) {
    final target = url.split('#').first;
    if (target.isEmpty) return null;
    final resolved = resolveHref(sections[fromSection].href, target);
    final index = sections.indexWhere((section) => section.href == resolved);
    return index < 0 ? null : index;
  }

  /// Bytes for an `<img src>` used inside [section].
  Uint8List? imageFor(EpubSection section, String src) {
    if (src.startsWith('data:')) return null;
    final resolved = resolveHref(section.href, Uri.decodeFull(src));
    final exact = images[resolved];
    if (exact != null) return exact;
    // Some books reference images inconsistently; fall back to file name.
    final name = resolved.split('/').last;
    for (final entry in images.entries) {
      if (entry.key.split('/').last == name) return entry.value;
    }
    return null;
  }
}

/// Resolves [target] relative to the file at [baseHref] ("a/b.xhtml").
String resolveHref(String baseHref, String target) {
  final baseParts = baseHref.split('/')..removeLast();
  for (final part in target.split('/')) {
    if (part == '..') {
      if (baseParts.isNotEmpty) baseParts.removeLast();
    } else if (part != '.' && part.isNotEmpty) {
      baseParts.add(part);
    }
  }
  return baseParts.join('/');
}

/// Parses EPUB bytes into [EpubBookData]. Self-contained (no Flutter or app
/// state) so it can run on a background isolate.
Future<EpubBookData> parseEpubBook(List<int> bytes) async {
  final book = await epub.EpubReader.readBook(bytes);
  final package = book.Schema?.Package;
  final manifest = {
    for (final item
        in package?.Manifest?.Items ?? const <epub.EpubManifestItem>[])
      if (item.Id != null && item.Href != null) item.Id!: item.Href!,
  };
  final htmlFiles = book.Content?.Html ?? const {};

  // Table of contents entries, flattened with their nesting depth.
  final tocSource = <({String title, String? file, int depth})>[];
  void addChapters(List<epub.EpubChapter>? chapters, int depth) {
    for (final chapter in chapters ?? const <epub.EpubChapter>[]) {
      final title = chapter.Title?.trim();
      if (title != null && title.isNotEmpty) {
        tocSource.add((
          title: title,
          file: chapter.ContentFileName,
          depth: depth,
        ));
      }
      addChapters(chapter.SubChapters, depth + 1);
    }
  }

  addChapters(book.Chapters, 0);

  final sections = <EpubSection>[];
  final spine = package?.Spine?.Items ?? const <epub.EpubSpineItemRef>[];
  String? lastTitle;
  for (var i = 0; i < spine.length; i++) {
    final idref = spine[i].IdRef ?? '';
    final href = manifest[idref];
    if (href == null) continue;
    final markup = htmlFiles[href]?.Content;
    if (markup == null) continue;
    final body = _bodyOf(markup);
    final text = _plainText(body);
    final blocks = _blocks(body);
    final hasImage = RegExp(
      r'<(img|image|svg)\b',
      caseSensitive: false,
    ).hasMatch(body);
    if (text.trim().isEmpty && !hasImage) continue;
    final tocTitle = tocSource
        .where((entry) => entry.file == href)
        .map((entry) => entry.title)
        .firstOrNull;
    // A chapter split across files keeps its title on the following files.
    final title = tocTitle ?? lastTitle ?? book.Title ?? 'Section ${i + 1}';
    lastTitle = title;
    sections.add(
      EpubSection(
        spineIndex: i,
        idref: idref,
        href: href,
        title: title,
        bodyHtml: body,
        textLength: text.length,
        blockCount: blocks.count,
        blockPath: blocks.path,
        blocks: splitHtmlBlocks(body),
      ),
    );
  }

  final toc = <EpubTocEntry>[];
  for (final entry in tocSource) {
    final index = sections.indexWhere((section) => section.href == entry.file);
    if (index >= 0) {
      toc.add(
        EpubTocEntry(
          title: entry.title,
          sectionIndex: index,
          depth: entry.depth,
        ),
      );
    }
  }

  final images = <String, Uint8List>{
    for (final entry in (book.Content?.Images ?? const {}).entries)
      if (entry.value.Content != null)
        entry.key: Uint8List.fromList(entry.value.Content!),
  };

  return EpubBookData(
    title: book.Title ?? '',
    sections: sections,
    toc: toc,
    images: images,
  );
}

const _voidTags = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'source',
  'track',
  'wbr',
  'image',
  'path',
  'rect',
  'circle',
  'use',
};

/// EPUB files are XHTML, where `<a id="x"/>` is a complete element. An HTML
/// parser reads it as an *unclosed* `<a>` that swallows everything after
/// it, so expand self-closing non-void tags into open/close pairs.
String _expandSelfClosing(String markup) => markup.replaceAllMapped(
  RegExp(r'<([a-zA-Z][\w:-]*)((?:\s[^<>]*?)?)\s*/>'),
  (match) {
    final tag = match.group(1)!;
    if (_voidTags.contains(tag.toLowerCase())) return match.group(0)!;
    return '<$tag${match.group(2)}></$tag>';
  },
);

String _bodyOf(String markup) {
  final body = RegExp(
    r'<body[^>]*>([\s\S]*)</body>',
    caseSensitive: false,
  ).firstMatch(markup)?.group(1);
  return _expandSelfClosing(body ?? markup)
      .replaceAll(
        RegExp(r'<(style|script)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
        '',
      )
      .trim();
}

String _plainText(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll(RegExp(r'&[a-zA-Z#0-9]+;'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Finds the paragraph-level elements: the body's children, descending
/// through lone wrapper elements (Project Gutenberg books put a whole file
/// inside one `<div>`, which would otherwise make every position "start").
({int count, List<int> path}) _blocks(String body) {
  var elements = html_parser.parseFragment(body).children;
  final path = <int>[];
  while (elements.length == 1 && elements.first.children.length > 1) {
    // The only element child is always CFI step 2.
    path.add(2);
    elements = elements.first.children;
  }
  return (count: elements.length, path: path);
}
