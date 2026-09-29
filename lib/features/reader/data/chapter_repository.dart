import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

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

  static final _startsWithTitleCache = Expando<bool>();

  /// Whether [html] already opens with the chapter title as a heading (most
  /// chapters do), so the reader shouldn't print the title again. Worked out
  /// on first use and cached per chapter, so it costs one parse.
  bool get htmlStartsWithTitle =>
      _startsWithTitleCache[this] ??= _startsWithTitle(html, title);

  factory ChapterContent.fromJson(Map<String, dynamic> json) => ChapterContent(
    id: json['id'].toString(),
    title: json['title'] as String,
    slug: json['slug'] as String,
    order: json['order'] as int,
    html: json['content'] as String? ?? '',
  );

  static bool _startsWithTitle(String html, String title) {
    final elements = html_parser.parseFragment(html).children;
    if (elements.isEmpty) return false;
    final first = elements.first;
    if (!const {'h1', 'h2', 'h3', 'h4'}.contains(first.localName)) return false;
    String normalize(String value) =>
        value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final heading = normalize(first.text);
    final expected = normalize(title);
    return heading.isNotEmpty &&
        (heading == expected ||
            heading.contains(expected) ||
            expected.contains(heading));
  }
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
