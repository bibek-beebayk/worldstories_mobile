import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/catalogue/data/catalogue_repository.dart';

void main() {
  test('parses custom nested catalogue pagination', () {
    final result = CataloguePage.fromJson({
      'pagination': {'count': 13, 'page': 2, 'pages': 2, 'size': 12},
      'results': [
        {'title': 'A story', 'slug': 'a-story'},
      ],
    });
    expect(result.page, 2);
    expect(result.pages, 2);
    expect(result.count, 13);
    expect(result.stories.single.slug, 'a-story');
  });

  test('only emits enabled catalogue filters', () {
    final params = const CatalogueQuery(
      search: 'raven',
      hasAudio: true,
      genreIds: {2, 4},
      categoryIds: {7},
      language: 'en',
      country: 'US',
      storyType: '3',
      status: 'completed',
    ).toParameters();
    expect(params['q'], 'raven');
    expect(params['has_audio'], isTrue);
    expect(params['genres'], '2,4');
    expect(params['categories'], '7');
    expect(params['country'], 'US');
    expect(params['story_type'], '3');
    expect(params['status'], 'completed');
    expect(params, isNot(contains('has_video')));
  });

  test('emits selected mood slugs', () {
    const query = CatalogueQuery(moodSlugs: {'cozy', 'hopeful'});

    expect(
      query.toParameters()['moods'],
      anyOf('cozy,hopeful', 'hopeful,cozy'),
    );
  });
}
