import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/search/data/search_repository.dart';

void main() {
  test('parses independently paginated search groups', () {
    Map<String, dynamic> group(List<Map<String, dynamic>> results, int page) =>
        {
          'pagination': {'page': page, 'pages': 3},
          'results': results,
        };
    final result = SearchResults.fromJson({
      'titles': group([
        {'title': 'The Raven', 'slug': 'the-raven'},
      ], 1),
      'authors': group([
        {'id': 2, 'name': 'Poe', 'stories_count': 1},
      ], 2),
      'chapters': group([
        {
          'story_slug': 'the-raven',
          'story_title': 'The Raven',
          'chapter_slug': 'the-raven',
          'chapter_title': 'The Raven',
          'excerpt': 'Once upon',
        },
      ], 3),
    });
    expect(result.titles.results.single.slug, 'the-raven');
    expect(result.authors.page, 2);
    expect(result.chapters.page, 3);
  });
}
