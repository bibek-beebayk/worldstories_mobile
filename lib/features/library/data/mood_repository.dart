import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => MoodRepository(ref.watch(apiClientProvider)),
);

final class Mood {
  const Mood({
    required this.slug,
    required this.name,
    required this.icon,
    required this.description,
    required this.storiesCount,
  });
  final String slug;
  final String name;
  final String icon;
  final String description;
  final int storiesCount;
  factory Mood.fromJson(Map<String, dynamic> json) => Mood(
    slug: json['slug'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String? ?? '✨',
    description: json['description'] as String? ?? '',
    storiesCount: json['stories_count'] as int? ?? 0,
  );
}

final class MoodRepository {
  const MoodRepository(this._client);
  final ApiClient _client;

  Future<List<Mood>> fetchList() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('moods/');
      return (response.data!['moods'] as List)
          .map((item) => Mood.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
