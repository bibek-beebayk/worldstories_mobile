import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../home/data/home_repository.dart';

final class SearchPage<T> {
  const SearchPage({
    required this.results,
    required this.page,
    required this.pages,
  });
  final List<T> results;
  final int page;
  final int pages;

  factory SearchPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final pagination = Map<String, dynamic>.from(json['pagination'] as Map);
    return SearchPage(
      results: (json['results'] as List)
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList(),
      page: pagination['page'] as int,
      pages: pagination['pages'] as int,
    );
  }
}

final class AuthorResult {
  const AuthorResult({
    required this.id,
    required this.name,
    required this.count,
  });
  final int id;
  final String name;
  final int count;
  factory AuthorResult.fromJson(Map<String, dynamic> json) => AuthorResult(
    id: json['id'] as int,
    name: json['name'] as String,
    count: json['stories_count'] as int? ?? 0,
  );
}

final class ChapterResult {
  const ChapterResult({
    required this.storySlug,
    required this.storyTitle,
    required this.chapterSlug,
    required this.chapterTitle,
    required this.excerpt,
  });
  final String storySlug;
  final String storyTitle;
  final String chapterSlug;
  final String chapterTitle;
  final String excerpt;
  factory ChapterResult.fromJson(Map<String, dynamic> json) => ChapterResult(
    storySlug: json['story_slug'] as String,
    storyTitle: json['story_title'] as String,
    chapterSlug: json['chapter_slug'] as String,
    chapterTitle: json['chapter_title'] as String,
    excerpt: json['excerpt'] as String? ?? '',
  );
}

final class SearchResults {
  const SearchResults({
    required this.titles,
    required this.authors,
    required this.chapters,
  });
  final SearchPage<StorySummary> titles;
  final SearchPage<AuthorResult> authors;
  final SearchPage<ChapterResult> chapters;
  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
    titles: SearchPage.fromJson(
      Map<String, dynamic>.from(json['titles'] as Map),
      StorySummary.fromJson,
    ),
    authors: SearchPage.fromJson(
      Map<String, dynamic>.from(json['authors'] as Map),
      AuthorResult.fromJson,
    ),
    chapters: SearchPage.fromJson(
      Map<String, dynamic>.from(json['chapters'] as Map),
      ChapterResult.fromJson,
    ),
  );
}

final class SearchRepository {
  const SearchRepository(this._client);
  final ApiClient _client;
  Future<SearchResults> search(
    String query, {
    required int titlePage,
    required int authorPage,
    required int chapterPage,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'search/',
        queryParameters: {
          'q': query,
          'page': titlePage,
          'author_page': authorPage,
          'chapter_page': chapterPage,
        },
      );
      return SearchResults.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
