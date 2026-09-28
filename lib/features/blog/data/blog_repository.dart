import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final blogRepositoryProvider = Provider<BlogRepository>(
  (ref) => BlogRepository(ref.watch(apiClientProvider)),
);

final class BlogLinkedStory {
  const BlogLinkedStory({
    required this.slug,
    required this.title,
    required this.coverImage,
  });
  final String slug;
  final String title;
  final String? coverImage;
  factory BlogLinkedStory.fromJson(Map<String, dynamic> json) =>
      BlogLinkedStory(
        slug: json['slug'] as String,
        title: json['title'] as String,
        coverImage: json['cover_image'] as String?,
      );
}

final class BlogLinkedBlog {
  const BlogLinkedBlog({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.coverImage,
  });
  final String slug;
  final String title;
  final String excerpt;
  final String? coverImage;
  factory BlogLinkedBlog.fromJson(Map<String, dynamic> json) => BlogLinkedBlog(
    slug: json['slug'] as String,
    title: json['title'] as String,
    excerpt: json['excerpt'] as String? ?? '',
    coverImage: json['cover_image'] as String?,
  );
}

final class BlogSummary {
  const BlogSummary({
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.coverImage,
    required this.authorName,
  });
  final String slug;
  final String title;
  final String excerpt;
  final String? coverImage;
  final String? authorName;
  factory BlogSummary.fromJson(Map<String, dynamic> json) => BlogSummary(
    slug: json['slug'] as String,
    title: json['title'] as String,
    excerpt: json['excerpt'] as String? ?? '',
    coverImage: json['cover_image'] as String?,
    authorName: json['author_name'] as String?,
  );
}

final class BlogDetail {
  const BlogDetail({
    required this.slug,
    required this.title,
    required this.content,
    required this.coverImage,
    required this.authorName,
    required this.linkedStories,
    required this.linkedBlogs,
  });
  final String slug;
  final String title;
  final String content;
  final String? coverImage;
  final String? authorName;
  final List<BlogLinkedStory> linkedStories;
  final List<BlogLinkedBlog> linkedBlogs;
  factory BlogDetail.fromJson(Map<String, dynamic> json) => BlogDetail(
    slug: json['slug'] as String,
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    coverImage: json['cover_image'] as String?,
    authorName: json['author_name'] as String?,
    linkedStories: (json['linked_stories'] as List? ?? const [])
        .map(
          (item) =>
              BlogLinkedStory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    linkedBlogs: (json['linked_blogs'] as List? ?? const [])
        .map(
          (item) =>
              BlogLinkedBlog.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

final class BlogPage {
  const BlogPage({
    required this.posts,
    required this.page,
    required this.pages,
  });
  final List<BlogSummary> posts;
  final int page;
  final int pages;
  factory BlogPage.fromJson(Map<String, dynamic> json) {
    final pagination = Map<String, dynamic>.from(json['pagination'] as Map);
    return BlogPage(
      posts: (json['results'] as List)
          .map(
            (item) =>
                BlogSummary.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      page: pagination['page'] as int,
      pages: pagination['pages'] as int,
    );
  }
}

final class BlogRepository {
  const BlogRepository(this._client);
  final ApiClient _client;

  Future<BlogPage> fetchList({int page = 1}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'blog/',
        queryParameters: {'page': page},
      );
      return BlogPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<BlogDetail> fetchDetail(String slug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'blog/${Uri.encodeComponent(slug)}/',
      );
      return BlogDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
