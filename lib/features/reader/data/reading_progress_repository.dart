import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';

final class ReadingProgress {
  const ReadingProgress({
    required this.chapterSlug,
    required this.progress,
    required this.overallProgress,
  });
  final String? chapterSlug;
  final double progress;
  final double overallProgress;
  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      ReadingProgress(
        chapterSlug: json['chapter_slug'] as String?,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        overallProgress: (json['overall_progress'] as num?)?.toDouble() ?? 0,
      );
}

final class ProgressSaveResult {
  const ProgressSaveResult({
    required this.storyCompleted,
    this.unlockedCountry,
    required this.unlockedAchievements,
  });
  final bool storyCompleted;
  final String? unlockedCountry;
  final List<Map<String, dynamic>> unlockedAchievements;
  factory ProgressSaveResult.fromJson(Map<String, dynamic> json) =>
      ProgressSaveResult(
        storyCompleted: json['story_completed'] as bool? ?? false,
        unlockedCountry: json['unlocked_country'] as String?,
        unlockedAchievements:
            (json['unlocked_achievements'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList(),
      );
}

final class ReadingProgressRepository {
  const ReadingProgressRepository(this._client);
  final ApiClient _client;

  Future<ReadingProgress?> fetch(String storySlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'reading-progress/${Uri.encodeComponent(storySlug)}/',
      );
      return ReadingProgress.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<ProgressSaveResult> save({
    required String storySlug,
    required String chapterSlug,
    required double progress,
  }) async {
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        'reading-progress/${Uri.encodeComponent(storySlug)}/',
        data: {
          'chapter_slug': chapterSlug,
          'progress': progress.clamp(0.0, 1.0),
        },
      );
      return ProgressSaveResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
