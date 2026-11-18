import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../home/data/home_repository.dart';

final class CataloguePage {
  const CataloguePage({
    required this.stories,
    required this.page,
    required this.pages,
    required this.count,
  });
  final List<StorySummary> stories;
  final int page;
  final int pages;
  final int count;

  factory CataloguePage.fromJson(Map<String, dynamic> json) {
    final pagination = Map<String, dynamic>.from(json['pagination'] as Map);
    return CataloguePage(
      stories: (json['results'] as List)
          .map(
            (item) =>
                StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      page: pagination['page'] as int,
      pages: pagination['pages'] as int,
      count: pagination['count'] as int,
    );
  }
}

final class CatalogueQuery {
  const CatalogueQuery({
    this.page = 1,
    this.search = '',
    this.sort = 'recent',
    this.hasAudio = false,
    this.hasSummary = false,
    this.hasReadAlong = false,
    this.genreIds = const {},
    this.categoryIds = const {},
    this.moodSlugs = const {},
    this.language = 'all',
    this.country = 'all',
    this.storyType = 'all',
    this.status = 'all',
  });
  final int page;
  final String search;
  final String sort;
  final bool hasAudio;
  final bool hasSummary;
  final bool hasReadAlong;
  final Set<int> genreIds;
  final Set<int> categoryIds;
  final Set<String> moodSlugs;
  final String language;
  final String country;
  final String storyType;
  final String status;

  Map<String, dynamic> toParameters() => {
    'page': page,
    'sort': sort,
    if (search.isNotEmpty) 'q': search,
    if (hasAudio) 'has_audio': true,
    if (hasSummary) 'has_summary': true,
    if (hasReadAlong) 'has_read_along': true,
    if (genreIds.isNotEmpty) 'genres': genreIds.join(','),
    if (categoryIds.isNotEmpty) 'categories': categoryIds.join(','),
    if (moodSlugs.isNotEmpty) 'moods': moodSlugs.join(','),
    if (language != 'all') 'language': language,
    if (country != 'all') 'country': country,
    if (storyType != 'all') 'story_type': storyType,
    if (status != 'all') 'status': status,
  };
}

final class FilterOption {
  const FilterOption({required this.value, required this.label});
  final String value;
  final String label;
}

final class CatalogueFilters {
  const CatalogueFilters({
    required this.genres,
    required this.categories,
    required this.languages,
    required this.countries,
    required this.storyTypes,
  });
  final List<FilterOption> genres;
  final List<FilterOption> categories;
  final List<FilterOption> languages;
  final List<FilterOption> countries;
  final List<FilterOption> storyTypes;
}

final class CatalogueRepository {
  const CatalogueRepository(this._client);
  final ApiClient _client;

  Future<CataloguePage> fetch(CatalogueQuery query) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/',
        queryParameters: query.toParameters(),
      );
      return CataloguePage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<CatalogueFilters> fetchFilters() async {
    try {
      final responses = await Future.wait([
        _client.dio.get<Map<String, dynamic>>('discover/'),
        _client.dio.get<Map<String, dynamic>>('story-map/'),
      ]);
      final discover = responses[0].data!;
      final map = responses[1].data!;
      List<FilterOption> objectOptions(String key, String valueKey) =>
          (discover[key] as List)
              .map(
                (item) => FilterOption(
                  value: (item as Map)[valueKey].toString(),
                  label: item['name'] as String,
                ),
              )
              .toList();
      return CatalogueFilters(
        genres: objectOptions('genres', 'id'),
        categories: objectOptions('categories', 'id'),
        storyTypes: objectOptions('story_types', 'id'),
        languages: (discover['languages'] as List)
            .map(
              (item) => FilterOption(
                value: (item as Map)['value'] as String,
                label: item['label'] as String,
              ),
            )
            .toList(),
        countries: (map['countries'] as List)
            .map(
              (item) => FilterOption(
                value: (item as Map)['code'] as String,
                label: item['name'] as String,
              ),
            )
            .toList(),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
