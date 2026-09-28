import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/reader/data/chapter_repository.dart';

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
}
