import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import 'html_blocks.dart';

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
  static final _blocksCache = Expando<List<String>>();

  /// [html] split into paragraph-level blocks (see [splitHtmlBlocks]),
  /// computed once per chapter.
  List<String> get blocks => _blocksCache[this] ??= splitHtmlBlocks(html);

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
      final chapter = ChapterContent.fromJson(response.data!);
      // Parse the HTML off the UI thread, so a chapter (including one
      // prefetched while the reader finishes the previous one) arrives
      // ready to render without a stall.
      final html = chapter.html;
      final title = chapter.title;
      final prepared = await Isolate.run(
        () => (
          blocks: splitHtmlBlocks(html),
          startsWithTitle: ChapterContent._startsWithTitle(html, title),
        ),
      );
      ChapterContent._blocksCache[chapter] = prepared.blocks;
      ChapterContent._startsWithTitleCache[chapter] = prepared.startsWithTitle;
      return chapter;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
