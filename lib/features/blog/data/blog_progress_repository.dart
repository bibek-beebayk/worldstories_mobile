import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';
import '../../reader/data/quick_read_progress_repository.dart' show SimpleProgress;

final blogProgressRepositoryProvider = Provider<BlogProgressRepository>(
  (ref) => BlogProgressRepository(ref.watch(apiClientProvider)),
);

final class BlogProgressRepository {
  const BlogProgressRepository(this._client);
  final ApiClient _client;

  Future<SimpleProgress?> fetch(String blogSlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'blog-reading-progress/${Uri.encodeComponent(blogSlug)}/',
      );
      return SimpleProgress.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<void> save({required String blogSlug, required double progress}) async {
    try {
      await _client.dio.put<Map<String, dynamic>>(
        'blog-reading-progress/${Uri.encodeComponent(blogSlug)}/',
        data: {'progress': progress.clamp(0.0, 1.0)},
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
