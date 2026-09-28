import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/home/data/home_repository.dart';

void main() {
  test('parses the production home response sections', () {
    final snapshot = HomeSnapshot.fromJson({
      'featured_stories': [{}, {}],
      'weekly_spotlight': [{}],
      'new_trending': [{}, {}, {}],
      'more_to_explore': [],
      'quick_reads': [{}],
      'originals': [{}],
      'tabs': {
        'recommended': [{}],
        'popular': [{}],
        'new': [{}],
      },
      'sidebar': {
        'recommended': [{}],
        'stats': {'creators': 2, 'stories': 3, 'readers': 4},
      },
      'daily_story': {'story': {}},
    });

    expect(snapshot.featuredStories, 2);
    expect(snapshot.weeklySpotlight, hasLength(1));
    expect(snapshot.newTrending, hasLength(3));
    expect(snapshot.moreToExplore, isEmpty);
    expect(snapshot.hasDailyStory, isTrue);
    expect(snapshot.dailyStoryConfigured, isFalse);
    expect(snapshot.quickReads, hasLength(1));
    expect(snapshot.stats.readers, 4);
  });

  test('rejects a malformed list section', () {
    expect(
      () => HomeSnapshot.fromJson({
        'featured_stories': 'wrong',
        'weekly_spotlight': [],
        'new_trending': [],
        'more_to_explore': [],
        'quick_reads': [],
        'originals': [],
        'tabs': {'recommended': [], 'popular': [], 'new': []},
        'sidebar': {
          'recommended': [],
          'stats': {'creators': 0, 'stories': 0, 'readers': 0},
        },
      }),
      throwsFormatException,
    );
  });
}
