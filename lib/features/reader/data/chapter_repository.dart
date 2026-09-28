import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';

final class ChapterContent {
  const ChapterContent({
    required this.id,
    required this.title,
    required this.slug,
    required this.order,
    required this.html,
  });
  final String id;
  final String title;
  final String slug;
  final int order;
  final String html;
  factory ChapterContent.fromJson(Map<String, dynamic> json) => ChapterContent(
    id: json['id'].toString(),
    title: json['title'] as String,
    slug: json['slug'] as String,
    order: json['order'] as int,
    html: json['content'] as String? ?? '',
  );
}

final class ChapterRepository {
  const ChapterRepository(this._client);
  final ApiClient _client;
  Future<ChapterContent> fetch({
    required String storySlug,
    required String chapterSlug,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/chapters/${Uri.encodeComponent(chapterSlug)}/',
        queryParameters: {'type': 'text'},
      );
      return ChapterContent.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
