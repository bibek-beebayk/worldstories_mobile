import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';

final class HomeSnapshot {
  const HomeSnapshot({
    required this.featured,
    required this.weeklySpotlight,
    required this.newTrending,
    required this.moreToExplore,
    required this.quickReads,
    required this.originals,
    required this.recommended,
    required this.popular,
    required this.newStories,
    required this.sidebarRecommended,
    required this.stats,
    required this.dailyStoryConfigured,
    required this.dailyStory,
  });

  final List<StorySummary> featured;
  final List<StorySummary> weeklySpotlight;
  final List<StorySummary> newTrending;
  final List<StorySummary> moreToExplore;
  final List<StorySummary> quickReads;
  final List<StorySummary> originals;
  final List<StorySummary> recommended;
  final List<StorySummary> popular;
  final List<StorySummary> newStories;
  final List<StorySummary> sidebarRecommended;
  final CommunityStats stats;
  final bool dailyStoryConfigured;
  final StorySummary? dailyStory;

  int get featuredStories => featured.length;
  bool get hasDailyStory => dailyStory != null;

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) => HomeSnapshot(
    featured: _stories(json, 'featured_stories'),
    weeklySpotlight: _stories(json, 'weekly_spotlight'),
    newTrending: _stories(json, 'new_trending'),
    moreToExplore: _stories(json, 'more_to_explore'),
    quickReads: _stories(json, 'quick_reads'),
    originals: _stories(json, 'originals'),
    recommended: _nestedStories(json, 'tabs', 'recommended'),
    popular: _nestedStories(json, 'tabs', 'popular'),
    newStories: _nestedStories(json, 'tabs', 'new'),
    sidebarRecommended: _nestedStories(json, 'sidebar', 'recommended'),
    stats: CommunityStats.fromJson(
      Map<String, dynamic>.from((json['sidebar'] as Map)['stats'] as Map),
    ),
    dailyStoryConfigured:
        json['daily_story'] is Map &&
        (json['daily_story'] as Map)['configured'] == true,
    dailyStory:
        json['daily_story'] is Map && (json['daily_story'] as Map)['story'] is Map
        ? StorySummary.fromJson(
            Map<String, dynamic>.from(
              (json['daily_story'] as Map)['story'] as Map,
            ),
          )
        : null,
  );

  static List<StorySummary> _stories(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('$key was not a list.');
    return value
        .map(
          (item) =>
              StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static List<StorySummary> _nestedStories(
    Map<String, dynamic> json,
    String parent,
    String key,
  ) => _stories(Map<String, dynamic>.from(json[parent] as Map), key);
}

final class CommunityStats {
  const CommunityStats({
    required this.creators,
    required this.stories,
    required this.readers,
  });
  final int creators;
  final int stories;
  final int readers;

  factory CommunityStats.fromJson(Map<String, dynamic> json) => CommunityStats(
    creators: json['creators'] as int? ?? 0,
    stories: json['stories'] as int? ?? 0,
    readers: json['readers'] as int? ?? 0,
  );
}

final class StorySummary {
  const StorySummary({
    required this.title,
    required this.slug,
    this.coverImage,
    this.author,
    this.storyType,
    this.views,
    this.rating,
  });
  final String title;
  final String slug;
  final String? coverImage;
  final String? author;
  final String? storyType;
  final int? views;
  final double? rating;

  factory StorySummary.fromJson(Map<String, dynamic> json) => StorySummary(
    title: json['title'] as String? ?? 'Untitled',
    slug: json['slug'] as String? ?? '',
    coverImage: json['cover_image'] as String?,
    author: json['author'] is Map
        ? (json['author'] as Map)['name'] as String?
        : json['author'] as String?,
    storyType: json['story_type'] as String?,
    views: (json['views'] as num?)?.toInt(),
    rating: (json['rating'] as num?)?.toDouble(),
  );
}

final class HomeRepository {
  const HomeRepository(this._client);
  final ApiClient _client;

  Future<HomeSnapshot> fetchHome() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('home/');
      final data = response.data;
      if (data == null) throw const FormatException('Home response was empty.');
      return HomeSnapshot.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
