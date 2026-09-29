import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../home/data/home_repository.dart';

final class StoryChapter {
  const StoryChapter({
    required this.title,
    required this.slug,
    required this.order,
  });
  final String title;
  final String slug;
  final int order;
  factory StoryChapter.fromJson(Map<String, dynamic> json) => StoryChapter(
    title: json['title'] as String,
    slug: json['slug'] as String,
    order: json['order'] as int,
  );
}

final class StoryMedia {
  const StoryMedia({
    required this.title,
    required this.slug,
    this.readAlongAvailable = false,
    this.youtubeId,
    this.aspectRatio = 16 / 9,
  });
  final String title;
  final String slug;
  final bool readAlongAvailable;
  final String? youtubeId;
  final double aspectRatio;

  factory StoryMedia.fromJson(Map<String, dynamic> json) {
    final width = (json['width'] as num?)?.toDouble();
    final height = (json['height'] as num?)?.toDouble();
    final rawAspectRatio = json['aspect_ratio'];
    double? aspectRatio = switch (rawAspectRatio) {
      num value => value.toDouble(),
      String value when value.contains(':') => _parseRatio(value),
      String value => double.tryParse(value),
      _ => null,
    };
    if ((aspectRatio == null || aspectRatio <= 0) &&
        width != null &&
        width > 0 &&
        height != null &&
        height > 0) {
      aspectRatio = width / height;
    }

    return StoryMedia(
      title: json['title'] as String,
      slug: json['slug'] as String,
      readAlongAvailable: json['read_along_available'] as bool? ?? false,
      youtubeId: json['youtube_id'] as String?,
      aspectRatio: aspectRatio != null && aspectRatio > 0
          ? aspectRatio
          : 16 / 9,
    );
  }

  static double? _parseRatio(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final width = double.tryParse(parts.first.trim());
    final height = double.tryParse(parts.last.trim());
    if (width == null || width <= 0 || height == null || height <= 0) {
      return null;
    }
    return width / height;
  }
}

final class StoryAuthor {
  const StoryAuthor({
    required this.name,
    required this.bio,
    required this.image,
    required this.storiesCount,
  });

  final String name;
  final String bio;
  final String? image;
  final int storiesCount;

  factory StoryAuthor.fromJson(Map<String, dynamic> json) => StoryAuthor(
    name: json['name'] as String? ?? 'Unknown author',
    bio: json['bio'] as String? ?? '',
    image: json['image'] as String?,
    storiesCount: json['stories_count'] as int? ?? 0,
  );
}

final class StoryDetail {
  const StoryDetail({
    required this.title,
    required this.slug,
    required this.about,
    required this.summary,
    required this.storyType,
    required this.language,
    required this.coverImage,
    required this.author,
    required this.authorDetails,
    required this.publishedLabel,
    required this.rating,
    required this.views,
    required this.isFavorite,
    required this.favoritesCount,
    required this.reviewsCount,
    required this.pdfFile,
    required this.epubFile,
    required this.chapters,
    required this.audios,
    required this.videos,
    required this.tags,
    required this.themes,
    required this.similarStories,
  });
  final String title;
  final String slug;
  final String about;
  final String summary;
  final String storyType;
  final String language;
  final String? coverImage;
  final String? author;
  final StoryAuthor? authorDetails;
  final String? publishedLabel;
  final double rating;
  final int views;
  final bool isFavorite;
  final int favoritesCount;
  final int reviewsCount;
  final String? pdfFile;
  final String? epubFile;
  final List<StoryChapter> chapters;
  final List<StoryMedia> audios;
  final List<StoryMedia> videos;
  final List<String> tags;
  final List<String> themes;
  final List<StorySummary> similarStories;

  factory StoryDetail.fromJson(Map<String, dynamic> json) {
    List<String> names(String key) => (json[key] as List? ?? const [])
        .map((item) => (item as Map)['name'] as String)
        .toList();
    final rawAuthor = json['author'];
    final authorDetails = rawAuthor is Map
        ? StoryAuthor.fromJson(Map<String, dynamic>.from(rawAuthor))
        : rawAuthor is String && rawAuthor.isNotEmpty
        ? StoryAuthor(name: rawAuthor, bio: '', image: null, storiesCount: 0)
        : null;
    return StoryDetail(
      title: json['title'] as String,
      slug: json['slug'] as String,
      about: json['about'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      storyType: json['story_type'] as String? ?? '',
      language: json['language'] as String? ?? '',
      coverImage: json['cover_image'] as String?,
      author: authorDetails?.name,
      authorDetails: authorDetails,
      publishedLabel: json['published_date_label'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      views: json['views'] as int? ?? 0,
      isFavorite: json['is_favorite'] as bool? ?? false,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      pdfFile: json['pdf_file'] as String?,
      epubFile: json['epub_file'] as String?,
      chapters: (json['chapters'] as List? ?? const [])
          .map(
            (item) =>
                StoryChapter.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      audios: (json['audios'] as List? ?? const [])
          .map(
            (item) =>
                StoryMedia.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      videos: (json['videos'] as List? ?? const [])
          .map(
            (item) =>
                StoryMedia.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      tags: names('tags'),
      themes: names('themes'),
      similarStories: (json['similar_stories'] as List? ?? const [])
          .map(
            (item) =>
                StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

final class StoryDetailRepository {
  const StoryDetailRepository(this._client);
  final ApiClient _client;
  Future<StoryDetail> fetch(String slug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(slug)}/',
      );
      return StoryDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
