import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(apiClientProvider)),
);

final class Review {
  const Review({
    required this.id,
    required this.username,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
  final int id;
  final String username;
  final int rating;
  final String comment;
  final DateTime createdAt;
  factory Review.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] as Map);
    return Review(
      id: json['id'] as int,
      username: user['username'] as String? ?? user['email'] as String? ?? '',
      rating: json['rating'] as int,
      comment: json['comment'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

final class ReviewPage {
  const ReviewPage({
    required this.reviews,
    required this.page,
    required this.pages,
  });
  final List<Review> reviews;
  final int page;
  final int pages;
  factory ReviewPage.fromJson(Map<String, dynamic> json) {
    final pagination = Map<String, dynamic>.from(json['pagination'] as Map);
    return ReviewPage(
      reviews: (json['results'] as List)
          .map((item) => Review.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      page: pagination['page'] as int,
      pages: pagination['pages'] as int,
    );
  }
}

final class ReviewRepository {
  const ReviewRepository(this._client);
  final ApiClient _client;

  Future<ReviewPage> fetch(String storySlug, {int page = 1}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/reviews/',
        queryParameters: {'page': page},
      );
      return ReviewPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Review?> fetchMine(String storySlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/reviews/me/',
      );
      return Review.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<Review> submit({
    required String storySlug,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/reviews/',
        data: {'rating': rating, 'comment': comment},
      );
      return Review.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Review> updateMine({
    required String storySlug,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/reviews/me/',
        data: {'rating': rating, 'comment': comment},
      );
      return Review.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deleteMine(String storySlug) async {
    try {
      await _client.dio.delete<void>(
        'stories/${Uri.encodeComponent(storySlug)}/reviews/me/',
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
