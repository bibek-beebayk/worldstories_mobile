import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';
import '../../home/data/home_repository.dart';

final storyRecommendationsRepositoryProvider =
    Provider<StoryRecommendationsRepository>(
      (ref) => StoryRecommendationsRepository(ref.watch(apiClientProvider)),
    );

final class CompletionSection {
  const CompletionSection({required this.title, required this.stories});
  final String title;
  final List<StorySummary> stories;
  factory CompletionSection.fromJson(Map<String, dynamic> json) =>
      CompletionSection(
        title: json['title'] as String? ?? '',
        stories: (json['stories'] as List? ?? const [])
            .map(
              (item) =>
                  StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

final class CompletionScreenData {
  const CompletionScreenData({
    required this.storyTitle,
    required this.countryName,
    required this.primary,
    required this.sections,
  });
  final String storyTitle;
  final String? countryName;
  final StorySummary? primary;
  final List<CompletionSection> sections;
  factory CompletionScreenData.fromJson(Map<String, dynamic> json) =>
      CompletionScreenData(
        storyTitle: json['story_title'] as String? ?? '',
        countryName: json['country_name'] as String?,
        primary: json['primary'] == null
            ? null
            : StorySummary.fromJson(
                Map<String, dynamic>.from(json['primary'] as Map),
              ),
        sections: (json['sections'] as List? ?? const [])
            .map(
              (item) => CompletionSection.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}

final class StoryRecommendationsRepository {
  const StoryRecommendationsRepository(this._client);
  final ApiClient _client;

  Future<List<StorySummary>> becauseFinished(String storySlug) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/because-finished/',
      );
      return response.data!
          .map(
            (item) =>
                StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<CompletionScreenData> completion(String storySlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/completion/',
      );
      return CompletionScreenData.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<StorySummary?> surprise({String? exclude, int? maxMinutes}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/surprise/',
        queryParameters: {'exclude': ?exclude, 'max_minutes': ?maxMinutes},
      );
      final story = response.data!['story'];
      return story == null
          ? null
          : StorySummary.fromJson(Map<String, dynamic>.from(story as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
