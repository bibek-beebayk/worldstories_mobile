import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => FavoriteRepository(ref.watch(apiClientProvider)),
);

final class FavoriteResult {
  const FavoriteResult({required this.isFavorite, required this.favoritesCount});
  final bool isFavorite;
  final int favoritesCount;
  factory FavoriteResult.fromJson(Map<String, dynamic> json) => FavoriteResult(
    isFavorite: json['is_favorite'] as bool? ?? false,
    favoritesCount: json['favorites_count'] as int? ?? 0,
  );
}

final class FavoriteRepository {
  const FavoriteRepository(this._client);
  final ApiClient _client;

  Future<FavoriteResult> setFavorite(String storySlug, bool favorite) async {
    try {
      final response = favorite
          ? await _client.dio.post<Map<String, dynamic>>(
              'stories/${Uri.encodeComponent(storySlug)}/favorite/',
            )
          : await _client.dio.delete<Map<String, dynamic>>(
              'stories/${Uri.encodeComponent(storySlug)}/favorite/',
            );
      return FavoriteResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
