import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../home/data/home_repository.dart';

final class NamedFacet {
  const NamedFacet({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });
  final int id;
  final String name;
  final String slug;
  final int count;
  factory NamedFacet.fromJson(Map<String, dynamic> json) => NamedFacet(
    id: json['id'] as int? ?? 0,
    name: json['name'] as String,
    slug: json['slug'] as String? ?? '',
    count: json['stories_count'] as int? ?? 0,
  );
}

final class DiscoverData {
  const DiscoverData({
    required this.genres,
    required this.categories,
    required this.storyTypes,
    required this.mostViewed,
    required this.highestRated,
    required this.newReleases,
    required this.hiddenGems,
  });
  final List<NamedFacet> genres;
  final List<NamedFacet> categories;
  final List<NamedFacet> storyTypes;
  final List<StorySummary> mostViewed;
  final List<StorySummary> highestRated;
  final List<StorySummary> newReleases;
  final List<StorySummary> hiddenGems;
  factory DiscoverData.fromJson(Map<String, dynamic> json) {
    List<NamedFacet> facets(String key) => (json[key] as List)
        .map(
          (item) => NamedFacet.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    List<StorySummary> stories(String key) => (json[key] as List)
        .map(
          (item) =>
              StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return DiscoverData(
      genres: facets('genres'),
      categories: facets('categories'),
      storyTypes: facets('story_types'),
      mostViewed: stories('most_viewed'),
      highestRated: stories('highest_rated'),
      newReleases: stories('new_releases'),
      hiddenGems: stories('hidden_gems'),
    );
  }
}

final class TrendingData {
  const TrendingData({
    required this.mostViewed,
    required this.highestRated,
    required this.mostFavorited,
    required this.mostDiscussed,
  });
  final List<StorySummary> mostViewed;
  final List<StorySummary> highestRated;
  final List<StorySummary> mostFavorited;
  final List<StorySummary> mostDiscussed;
  factory TrendingData.fromJson(Map<String, dynamic> json) {
    List<StorySummary> stories(String key) => (json[key] as List)
        .map(
          (item) =>
              StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return TrendingData(
      mostViewed: stories('most_viewed'),
      highestRated: stories('highest_rated'),
      mostFavorited: stories('most_favorited'),
      mostDiscussed: stories('most_discussed'),
    );
  }
}

final class CountrySummary {
  const CountrySummary({
    required this.code,
    required this.name,
    required this.count,
  });
  final String code;
  final String name;
  final int count;
  factory CountrySummary.fromJson(Map<String, dynamic> json) => CountrySummary(
    code: json['code'] as String,
    name: json['name'] as String,
    count: json['stories_count'] as int,
  );
}

final class StoryMapData {
  const StoryMapData({required this.countries, required this.totalStories});
  final List<CountrySummary> countries;
  final int totalStories;
  factory StoryMapData.fromJson(Map<String, dynamic> json) => StoryMapData(
    countries: (json['countries'] as List)
        .map(
          (item) =>
              CountrySummary.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    totalStories: json['total_stories'] as int,
  );
}

final class DiscoveryRepository {
  const DiscoveryRepository(this._client);
  final ApiClient _client;
  Future<T> _get<T>(String path, T Function(Map<String, dynamic>) parse) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(path);
      return parse(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<DiscoverData> discover() => _get('discover/', DiscoverData.fromJson);
  Future<TrendingData> trending() => _get('trending/', TrendingData.fromJson);
  Future<StoryMapData> storyMap() => _get('story-map/', StoryMapData.fromJson);
}
