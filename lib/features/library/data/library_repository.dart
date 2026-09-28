import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';
import '../../home/data/home_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(apiClientProvider)),
);

/// One row from any `/auth/library/*` tab. Each endpoint's serializer wraps a
/// `story: StoryListSerializer` plus a handful of tab-specific fields
/// (`chapter_slug`/`audio_progress`/`rating`/etc. — see API_REFERENCE.md §6).
/// Rather than one bespoke model per endpoint for what is ultimately the same
/// "story card + a couple of extra facts" shape everywhere, this keeps the
/// full decoded JSON in [raw] and exposes typed getters for the fields a
/// given tab actually displays.
final class LibraryItem {
  const LibraryItem({required this.story, required this.raw});
  final StorySummary story;
  final Map<String, dynamic> raw;
  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
    story: StorySummary.fromJson(Map<String, dynamic>.from(json['story'] as Map)),
    raw: json,
  );

  double? get overallProgress => (raw['overall_progress'] as num?)?.toDouble();
  int? get remainingMinutes => raw['remaining_minutes'] as int?;
  String? get chapterTitle => raw['chapter_title'] as String?;
  String? get audioTitle => raw['audio_title'] as String?;
  String? get videoTitle => raw['video_title'] as String?;
  bool? get completed => raw['completed'] as bool?;
  double? get historyProgress => (raw['progress'] as num?)?.toDouble();
  int? get rating => raw['rating'] as int?;
  String? get comment => raw['comment'] as String?;
}

final class LibraryPage {
  const LibraryPage({required this.items, required this.page, required this.pages});
  final List<LibraryItem> items;
  final int page;
  final int pages;
  factory LibraryPage.fromJson(Map<String, dynamic> json) {
    final pagination = Map<String, dynamic>.from(json['pagination'] as Map);
    return LibraryPage(
      items: (json['results'] as List)
          .map((item) => LibraryItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      page: pagination['page'] as int,
      pages: pagination['pages'] as int,
    );
  }
}

final class LibraryRepository {
  const LibraryRepository(this._client);
  final ApiClient _client;

  Future<LibraryPage> fetch(String endpoint, {int page = 1}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/library/$endpoint/',
        queryParameters: {'page': page},
      );
      return LibraryPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `recommendations` is the one tab that isn't paginated and returns bare
  /// `StoryListSerializer` objects rather than `{story: ...}` wrappers.
  Future<List<StorySummary>> fetchRecommendations({
    bool quickReadOnly = false,
    String? exclude,
  }) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        'auth/library/recommendations/',
        queryParameters: {
          if (quickReadOnly) 'quick_read': true,
          'exclude': ?exclude,
        },
      );
      return response.data!
          .map((item) => StorySummary.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
