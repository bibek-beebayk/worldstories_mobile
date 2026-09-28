import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final videoProgressRepositoryProvider = Provider<VideoProgressRepository>(
  (ref) => VideoProgressRepository(ref.watch(apiClientProvider)),
);

final class VideoProgress {
  const VideoProgress({
    required this.videoSlug,
    required this.progress,
    required this.positionSeconds,
  });
  final String? videoSlug;
  final double progress;
  final double positionSeconds;
  factory VideoProgress.fromJson(Map<String, dynamic> json) => VideoProgress(
    videoSlug: json['video_slug'] as String?,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    positionSeconds: (json['position_seconds'] as num?)?.toDouble() ?? 0,
  );
}

final class VideoProgressSaveResult {
  const VideoProgressSaveResult({
    required this.storyCompleted,
    this.unlockedCountry,
    required this.unlockedAchievements,
  });
  final bool storyCompleted;
  final String? unlockedCountry;
  final List<Map<String, dynamic>> unlockedAchievements;
  factory VideoProgressSaveResult.fromJson(Map<String, dynamic> json) =>
      VideoProgressSaveResult(
        storyCompleted: json['story_completed'] as bool? ?? false,
        unlockedCountry: json['unlocked_country'] as String?,
        unlockedAchievements:
            (json['unlocked_achievements'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList(),
      );
}

final class VideoProgressRepository {
  const VideoProgressRepository(this._client);
  final ApiClient _client;

  Future<VideoProgress?> fetch(String storySlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'video-progress/${Uri.encodeComponent(storySlug)}/',
      );
      return VideoProgress.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<VideoProgressSaveResult> save({
    required String storySlug,
    required String videoSlug,
    required double progress,
    required double positionSeconds,
    required double durationSeconds,
  }) async {
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        'video-progress/${Uri.encodeComponent(storySlug)}/',
        data: {
          'video_slug': videoSlug,
          'progress': progress.clamp(0.0, 1.0),
          'position_seconds': positionSeconds,
          'duration_seconds': durationSeconds,
        },
      );
      return VideoProgressSaveResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
