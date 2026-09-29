import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/reader/data/chapter_repository.dart';

ChapterContent _chapter(String title, String html) => ChapterContent.fromJson({
  'id': 1,
  'title': title,
  'slug': 'chapter',
  'order': 1,
  'content': html,
});

void main() {
  test('parses full chapter HTML payload', () {
    final chapter = ChapterContent.fromJson({
      'id': 4,
      'title': 'Chapter One',
      'slug': 'chapter-one',
      'order': 1,
      'content': '<p>Hello</p>',
    });
    expect(chapter.id, '4');
    expect(chapter.html, '<p>Hello</p>');
  });

  test('detects a chapter whose HTML opens with its title', () {
    final chapter = _chapter(
      'Episode 1: The Frozen Watches',
      '<h2><span style="font-size: 1.28em;">Episode 1:  The Frozen Watches'
          '</span></h2><p>Elias Voss hadn\'t slept.</p>',
    );
    expect(chapter.htmlStartsWithTitle, isTrue);
  });

  test('keeps the title when the HTML starts with body text', () {
    expect(
      _chapter('Chapter One', '<p>It was a dark night.</p>')
          .htmlStartsWithTitle,
      isFalse,
    );
    expect(
      _chapter('Chapter One', '<h2>A different heading</h2><p>Text</p>')
          .htmlStartsWithTitle,
      isFalse,
    );
  });
}
