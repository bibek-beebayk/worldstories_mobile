import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';
import '../../home/data/home_repository.dart';

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => JourneyRepository(ref.watch(apiClientProvider)),
);

final class Journey {
  const Journey({
    required this.slug,
    required this.title,
    required this.description,
    required this.type,
    required this.coverImage,
    required this.completed,
    required this.total,
    required this.isComplete,
  });
  final String slug;
  final String title;
  final String description;
  final String type;
  final String? coverImage;
  final int completed;
  final int total;
  final bool isComplete;
  factory Journey.fromJson(Map<String, dynamic> json) => Journey(
    slug: json['slug'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    type: json['type'] as String? ?? '',
    coverImage: json['cover_image'] as String?,
    completed: json['completed'] as int? ?? 0,
    total: json['total'] as int? ?? 0,
    isComplete: json['is_complete'] as bool? ?? false,
  );
}

final class JourneyItem {
  const JourneyItem({
    required this.position,
    required this.isRequired,
    required this.completed,
    required this.story,
  });
  final int position;
  final bool isRequired;
  final bool completed;
  final StorySummary story;
  factory JourneyItem.fromJson(Map<String, dynamic> json) => JourneyItem(
    position: json['position'] as int? ?? 0,
    isRequired: json['required'] as bool? ?? true,
    completed: json['completed'] as bool? ?? false,
    story: StorySummary.fromJson(Map<String, dynamic>.from(json['story'] as Map)),
  );
}

final class JourneyDetail {
  const JourneyDetail({required this.journey, required this.items});
  final Journey journey;
  final List<JourneyItem> items;
  factory JourneyDetail.fromJson(Map<String, dynamic> json) => JourneyDetail(
    journey: Journey.fromJson(json),
    items: (json['items'] as List? ?? const [])
        .map((item) => JourneyItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
  );
}

final class JourneyRepository {
  const JourneyRepository(this._client);
  final ApiClient _client;

  Future<List<Journey>> fetchList() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('journeys/');
      return (response.data!['journeys'] as List)
          .map((item) => Journey.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JourneyDetail> fetchDetail(String slug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'journeys/${Uri.encodeComponent(slug)}/',
      );
      return JourneyDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
