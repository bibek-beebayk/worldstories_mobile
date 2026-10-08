import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/reader/data/epub_book.dart';

EpubSection _section(int spine, String href, int length, int blocks) =>
    EpubSection(
      spineIndex: spine,
      idref: 'item$spine',
      href: href,
      title: 'Section $spine',
      bodyHtml: '<p>text</p>',
      textLength: length,
      blockCount: blocks,
    );

void main() {
  final book = EpubBookData(
    title: 'Book',
    sections: [
      _section(1, 'Text/ch1.xhtml', 100, 10),
      _section(2, 'Text/ch2.xhtml', 300, 20),
    ],
    toc: const [],
    images: {
      'Images/cover.jpg': Uint8List.fromList([1, 2, 3]),
    },
  );

  test('weights overall progress by section length', () {
    expect(book.overallProgress(0, 0), 0);
    expect(book.overallProgress(0, 1), closeTo(0.25, 1e-9));
    expect(book.overallProgress(1, 0.5), closeTo(0.625, 1e-9));
    final position = book.positionForOverall(0.625);
    expect(position.section, 1);
    expect(position.fraction, closeTo(0.5, 1e-9));
  });

  test('round-trips its own CFIs at paragraph precision', () {
    final cfi = book.cfiFor(1, 0.5);
    expect(cfi, 'epubcfi(/6/6[item2]!/4/22)');
    final position = book.positionForCfi(cfi)!;
    expect(position.section, 1);
    expect(position.fraction, closeTo(0.5, 1e-9));
  });

  test('reads CFIs written by epub.js and epub_view', () {
    final webCfi = book.positionForCfi('epubcfi(/6/4[item1]!/4/2/1:0)')!;
    expect(webCfi.section, 0);
    expect(webCfi.fraction, 0);
    final oldApp = book.positionForCfi('epubcfi(/6/6!/4[body]/10)')!;
    expect(oldApp.section, 1);
    expect(oldApp.fraction, closeTo(4 / 20, 1e-9));
    expect(book.positionForCfi('not a cfi'), isNull);
    expect(book.positionForCfi('epubcfi(/6/40!/4/2)'), isNull);
  });

  test('addresses blocks inside a lone wrapper element', () {
    final wrapped = EpubBookData(
      title: 'Book',
      sections: const [
        EpubSection(
          spineIndex: 0,
          idref: 'a',
          href: 'a.xhtml',
          title: 'A',
          bodyHtml: '',
          textLength: 10,
          blockCount: 40,
          blockPath: [2],
        ),
      ],
      toc: const [],
      images: const {},
    );
    final cfi = wrapped.cfiFor(0, 0.5);
    expect(cfi, 'epubcfi(/6/2[a]!/4/2/42)');
    expect(wrapped.positionForCfi(cfi)!.fraction, closeTo(0.5, 1e-9));
  });

  test('resolves relative image and link paths', () {
    expect(
      resolveHref('Text/ch1.xhtml', '../Images/cover.jpg'),
      'Images/cover.jpg',
    );
    expect(
      book.imageFor(book.sections.first, '../Images/cover.jpg'),
      isNotNull,
    );
    expect(book.sectionForLink(0, 'ch2.xhtml#note-3'), 1);
    expect(book.sectionForLink(0, 'https://example.com'), isNull);
  });
}
