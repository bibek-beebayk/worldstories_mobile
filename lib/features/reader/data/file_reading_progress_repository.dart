import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final fileReadingProgressRepositoryProvider =
    Provider<FileReadingProgressRepository>(
      (ref) => FileReadingProgressRepository(ref.watch(apiClientProvider)),
    );

enum FileReadingFormat {
  epub,
  pdf;

  String get wireValue => name;
}

final class FileReadingProgress {
  const FileReadingProgress({required this.progress, required this.position});
  final double progress;
  final String? position;
  factory FileReadingProgress.fromJson(Map<String, dynamic> json) =>
      FileReadingProgress(
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        position: json['position'] as String?,
      );
}

final class FileProgressSaveResult {
  const FileProgressSaveResult({
    required this.storyCompleted,
    this.unlockedCountry,
    required this.unlockedAchievements,
  });
  final bool storyCompleted;
  final String? unlockedCountry;
  final List<Map<String, dynamic>> unlockedAchievements;
  factory FileProgressSaveResult.fromJson(Map<String, dynamic> json) =>
      FileProgressSaveResult(
        storyCompleted: json['story_completed'] as bool? ?? false,
        unlockedCountry: json['unlocked_country'] as String?,
        unlockedAchievements:
            (json['unlocked_achievements'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList(),
      );
}

final class FileReadingProgressRepository {
  const FileReadingProgressRepository(this._client);
  final ApiClient _client;

  Future<FileReadingProgress?> fetch(
    String storySlug,
    FileReadingFormat format,
  ) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'file-reading-progress/${Uri.encodeComponent(storySlug)}/${format.wireValue}/',
      );
      return FileReadingProgress.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<FileProgressSaveResult> save({
    required String storySlug,
    required FileReadingFormat format,
    required double progress,
    String? position,
  }) async {
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        'file-reading-progress/${Uri.encodeComponent(storySlug)}/${format.wireValue}/',
        data: {'progress': progress.clamp(0.0, 1.0), 'position': ?position},
      );
      return FileProgressSaveResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
