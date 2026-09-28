import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final audioProgressRepositoryProvider = Provider<AudioProgressRepository>(
  (ref) => AudioProgressRepository(ref.watch(apiClientProvider)),
);

final class AudioProgress {
  const AudioProgress({
    required this.audioSlug,
    required this.progress,
    required this.positionSeconds,
  });
  final String? audioSlug;
  final double progress;
  final double positionSeconds;
  factory AudioProgress.fromJson(Map<String, dynamic> json) => AudioProgress(
    audioSlug: json['audio_slug'] as String?,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    positionSeconds: (json['position_seconds'] as num?)?.toDouble() ?? 0,
  );
}

final class AudioProgressSaveResult {
  const AudioProgressSaveResult({
    required this.storyCompleted,
    this.unlockedCountry,
    required this.unlockedAchievements,
  });
  final bool storyCompleted;
  final String? unlockedCountry;
  final List<Map<String, dynamic>> unlockedAchievements;
  factory AudioProgressSaveResult.fromJson(Map<String, dynamic> json) =>
      AudioProgressSaveResult(
        storyCompleted: json['story_completed'] as bool? ?? false,
        unlockedCountry: json['unlocked_country'] as String?,
        unlockedAchievements:
            (json['unlocked_achievements'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList(),
      );
}

final class AudioProgressRepository {
  const AudioProgressRepository(this._client);
  final ApiClient _client;

  Future<AudioProgress?> fetch(String storySlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'audio-progress/${Uri.encodeComponent(storySlug)}/',
      );
      return AudioProgress.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<AudioProgressSaveResult> save({
    required String storySlug,
    required String audioSlug,
    required double progress,
    required double positionSeconds,
    required double durationSeconds,
  }) async {
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        'audio-progress/${Uri.encodeComponent(storySlug)}/',
        data: {
          'audio_slug': audioSlug,
          'progress': progress.clamp(0.0, 1.0),
          'position_seconds': positionSeconds,
          'duration_seconds': durationSeconds,
        },
      );
      return AudioProgressSaveResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
