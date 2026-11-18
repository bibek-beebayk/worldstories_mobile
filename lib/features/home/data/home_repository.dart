import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../blog/data/blog_repository.dart';
import '../../watch/data/watch_repository.dart';

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
    this.featuredItems = const [],
    this.dailyItem,
    this.dailyReason = '',
    this.sections = const [],
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

  /// The ordered Featured lineup (stories and videos together).
  final List<FeaturedItem> featuredItems;

  /// Today's configured pick (story or video), when an editor set one.
  final FeaturedItem? dailyItem;
  final String dailyReason;

  /// The admin-managed homepage body, already ordered and resolved.
  final List<HomeSection> sections;

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
    featuredItems: _featuredItems(json),
    dailyItem: _dailyItem(json),
    dailyReason: json['daily_story'] is Map
        ? ((json['daily_story'] as Map)['featured_reason'] as String? ?? '')
        : '',
    sections: [
      for (final item in json['sections'] as List? ?? const [])
        if (item is Map) HomeSection.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  static List<FeaturedItem> _featuredItems(Map<String, dynamic> json) {
    final raw = json['featured_items'];
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map)
            ?FeaturedItem.maybeFromJson(Map<String, dynamic>.from(item)),
      ];
    }
    return [
      for (final story in _stories(json, 'featured_stories'))
        FeaturedItem(story: story),
    ];
  }

  static FeaturedItem? _dailyItem(Map<String, dynamic> json) {
    final daily = json['daily_story'];
    if (daily is! Map || daily['configured'] != true) return null;
    final video = daily['video'];
    if (video is Map) {
      return FeaturedItem(
        video: WatchVideo.fromJson(Map<String, dynamic>.from(video)),
      );
    }
    final story = daily['story'];
    if (story is Map) {
      return FeaturedItem(
        story: StorySummary.fromJson(Map<String, dynamic>.from(story)),
      );
    }
    return null;
  }

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

/// One entry of the Featured band: a story or a video.
final class FeaturedItem {
  const FeaturedItem({this.story, this.video});
  final StorySummary? story;
  final WatchVideo? video;

  static FeaturedItem? maybeFromJson(Map<String, dynamic> json) {
    if (json['kind'] == 'video' && json['video'] is Map) {
      return FeaturedItem(
        video: WatchVideo.fromJson(
          Map<String, dynamic>.from(json['video'] as Map),
        ),
      );
    }
    if (json['story'] is Map) {
      return FeaturedItem(
        story: StorySummary.fromJson(
          Map<String, dynamic>.from(json['story'] as Map),
        ),
      );
    }
    return null;
  }
}

/// One resolved section of the admin-managed homepage body
/// (`sections` in `GET /home/`). `type` is kept as the backend's string so a
/// newer backend's unknown types are simply skipped by the renderer.
final class HomeSection {
  const HomeSection({
    required this.id,
    required this.type,
    this.variant = 'standard',
    this.title = '',
    this.subtitle = '',
    this.icon = '',
    this.layout = 'grid',
    this.columnsMobile = 2,
    this.itemLimit = 12,
    this.allowRepeats = false,
    this.seeAllUrl = '',
    this.seeAllLabel = 'See all',
    this.config = const {},
    this.stories = const [],
    this.videos = const [],
    this.blogs = const [],
  });

  final int id;
  final String type;
  final String variant;
  final String title;
  final String subtitle;
  final String icon;
  final String layout;
  final int columnsMobile;
  final int itemLimit;
  final bool allowRepeats;
  final String seeAllUrl;
  final String seeAllLabel;
  final Map<String, dynamic> config;
  final List<StorySummary> stories;
  final List<WatchVideo> videos;
  final List<BlogSummary> blogs;

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final type = json['section_type'] as String? ?? '';
    final items = [
      for (final item in json['items'] as List? ?? const [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    return HomeSection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: type,
      variant: json['variant'] as String? ?? 'standard',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      layout: json['layout'] as String? ?? 'grid',
      columnsMobile: ((json['columns_mobile'] as num?)?.toInt() ?? 2).clamp(
        1,
        3,
      ),
      itemLimit: (json['item_limit'] as num?)?.toInt() ?? 12,
      allowRepeats: json['allow_repeats'] as bool? ?? false,
      seeAllUrl: json['see_all_url'] as String? ?? '',
      seeAllLabel: (json['see_all_label'] as String?)?.isNotEmpty == true
          ? json['see_all_label'] as String
          : 'See all',
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
      stories: type == 'stories_query' || type == 'stories_manual'
          ? items.map(StorySummary.fromJson).toList()
          : const [],
      videos: type == 'videos'
          ? items.map(WatchVideo.fromJson).toList()
          : const [],
      blogs: type == 'blogs' ? items.map(BlogSummary.fromJson).toList() : const [],
    );
  }
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
