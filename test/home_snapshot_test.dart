import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/home/data/home_repository.dart';

void main() {
  homeSectionTests();
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

Map<String, dynamic> _base(Map<String, dynamic> extra) => {
  'featured_stories': [
    {'title': 'F', 'slug': 'f'},
  ],
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
  ...extra,
};

void homeSectionTests() {
  test('parses admin-managed sections by type', () {
    final snapshot = HomeSnapshot.fromJson(
      _base({
        'sections': [
          {
            'id': 1,
            'section_type': 'stories_query',
            'variant': 'originals',
            'title': 'Originals',
            'layout': 'rail',
            'columns_mobile': 9,
            'items': [
              {'title': 'A', 'slug': 'a'},
            ],
          },
          {
            'id': 2,
            'section_type': 'videos',
            'items': [
              {
                'id': 5,
                'title': 'V',
                'slug': 'v',
                'youtube_id': 'yt',
                'aspect_ratio': '16:9',
                'thumbnail': 't',
                'story': null,
                'video_type': null,
                'duration_seconds': null,
              },
            ],
          },
          {
            'id': 3,
            'section_type': 'blogs',
            'items': [
              {'title': 'B', 'slug': 'b', 'excerpt': 'x'},
            ],
          },
          {'id': 4, 'section_type': 'explore_tiles', 'items': []},
        ],
      }),
    );
    expect(snapshot.sections.map((s) => s.type), [
      'stories_query',
      'videos',
      'blogs',
      'explore_tiles',
    ]);
    expect(snapshot.sections[0].stories.single.slug, 'a');
    expect(snapshot.sections[0].columnsMobile, 3);
    expect(snapshot.sections[1].videos.single.id, 5);
    expect(snapshot.sections[2].blogs.single.slug, 'b');
  });

  test('daily pick overrides the featured lineup only when configured', () {
    final configured = HomeSnapshot.fromJson(
      _base({
        'daily_story': {
          'configured': true,
          'featured_reason': 'Today',
          'story': null,
          'video': {
            'id': 9,
            'title': 'V',
            'youtube_id': 'y',
            'story': {'id': 1, 'title': 'S', 'slug': 's'},
          },
        },
      }),
    );
    expect(configured.dailyItem?.video?.id, 9);
    expect(configured.dailyReason, 'Today');

    final fallback = HomeSnapshot.fromJson(
      _base({
        'daily_story': {'configured': false, 'story': {'slug': 'f'}},
        'featured_items': [
          {
            'kind': 'story',
            'story': {'title': 'F', 'slug': 'f'},
          },
        ],
      }),
    );
    expect(fallback.dailyItem, isNull);
    expect(fallback.featuredItems.single.story?.slug, 'f');
    expect(_base({}).containsKey('sections'), isFalse);
    expect(HomeSnapshot.fromJson(_base({})).sections, isEmpty);
    expect(
      HomeSnapshot.fromJson(_base({})).featuredItems.single.story?.slug,
      'f',
    );
  });
}
