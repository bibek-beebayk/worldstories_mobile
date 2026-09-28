import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final quickReadProgressRepositoryProvider =
    Provider<QuickReadProgressRepository>(
      (ref) => QuickReadProgressRepository(ref.watch(apiClientProvider)),
    );

/// Covers both `quick-read-progress` and `blog-reading-progress` — both are
/// `{progress, updated_at}` with no completion signals, per the API docs.
final class SimpleProgress {
  const SimpleProgress({required this.progress});
  final double progress;
  factory SimpleProgress.fromJson(Map<String, dynamic> json) =>
      SimpleProgress(progress: (json['progress'] as num?)?.toDouble() ?? 0);
}

final class QuickReadProgressRepository {
  const QuickReadProgressRepository(this._client);
  final ApiClient _client;

  Future<SimpleProgress?> fetch(String storySlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'quick-read-progress/${Uri.encodeComponent(storySlug)}/',
      );
      return SimpleProgress.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<void> save({required String storySlug, required double progress}) async {
    try {
      await _client.dio.put<Map<String, dynamic>>(
        'quick-read-progress/${Uri.encodeComponent(storySlug)}/',
        data: {'progress': progress.clamp(0.0, 1.0)},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
