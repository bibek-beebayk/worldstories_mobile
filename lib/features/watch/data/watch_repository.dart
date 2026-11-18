import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final watchRepositoryProvider = Provider<WatchRepository>(
  (ref) => WatchRepository(ref.watch(apiClientProvider)),
);

final videoTypesProvider = FutureProvider<List<VideoType>>(
  (ref) => ref.watch(watchRepositoryProvider).fetchVideoTypes(),
);

/// Formats a duration as `h:mm:ss` or `m:ss`; empty when unknown/zero.
String formatVideoDuration(num? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

final class VideoType {
  const VideoType({required this.id, required this.name, this.videosCount = 0});
  final int id;
  final String name;
  final int videosCount;

  factory VideoType.fromJson(Map<String, dynamic> json) => VideoType(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    videosCount: (json['videos_count'] as num?)?.toInt() ?? 0,
  );
}

final class WatchStoryRef {
  const WatchStoryRef({
    required this.id,
    required this.title,
    required this.slug,
  });
  final int id;
  final String title;
  final String slug;

  static WatchStoryRef? maybeFromJson(Object? json) {
    if (json is! Map) return null;
    final slug = json['slug'];
    if (slug is! String) return null;
    return WatchStoryRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      slug: slug,
    );
  }
}

final class WatchVideo {
  const WatchVideo({
    required this.id,
    required this.title,
    required this.slug,
    required this.youtubeId,
    required this.aspectRatio,
    required this.thumbnail,
    this.durationSeconds,
    this.story,
    this.videoType,
  });
  final int id;
  final String title;
  final String slug;
  final String youtubeId;
  final num? durationSeconds;

  /// `"16:9"` or `"9:16"`.
  final String aspectRatio;
  final String thumbnail;
  final WatchStoryRef? story;
  final VideoType? videoType;

  bool get isPortrait => aspectRatio == '9:16';

  factory WatchVideo.fromJson(Map<String, dynamic> json) => WatchVideo(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    youtubeId: json['youtube_id'] as String? ?? '',
    durationSeconds: json['duration_seconds'] as num?,
    aspectRatio: json['aspect_ratio'] as String? ?? '16:9',
    thumbnail: json['thumbnail'] as String? ?? '',
    story: WatchStoryRef.maybeFromJson(json['story']),
    videoType: json['video_type'] is Map
        ? VideoType.fromJson(
            Map<String, dynamic>.from(json['video_type'] as Map),
          )
        : null,
  );
}

final class WatchVideoDetail {
  const WatchVideoDetail({required this.video, required this.suggested});
  final WatchVideo video;
  final List<WatchVideo> suggested;

  factory WatchVideoDetail.fromJson(Map<String, dynamic> json) =>
      WatchVideoDetail(
        video: WatchVideo.fromJson(json),
        suggested: [
          for (final item in json['suggested'] as List? ?? const [])
            WatchVideo.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
      );
}

final class WatchVideosPage {
  const WatchVideosPage({
    required this.videos,
    required this.count,
    required this.page,
    required this.pages,
  });
  final List<WatchVideo> videos;
  final int count;
  final int page;
  final int pages;

  bool get hasMore => page < pages;

  factory WatchVideosPage.fromJson(Map<String, dynamic> json) {
    final pagination = Map<String, dynamic>.from(
      json['pagination'] as Map? ?? const {},
    );
    final videos = [
      for (final item in json['results'] as List? ?? const [])
        WatchVideo.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    return WatchVideosPage(
      videos: videos,
      count: (pagination['count'] as num?)?.toInt() ?? videos.length,
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      pages: (pagination['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

final class WatchProgress {
  const WatchProgress({
    required this.videoId,
    required this.progress,
    required this.positionSeconds,
    this.durationSeconds,
  });
  final int videoId;
  final double progress;
  final double positionSeconds;
  final double? durationSeconds;

  /// Where playback should start: the saved position, unless the video was
  /// (practically) finished.
  double get startSeconds => progress >= 0.995 ? 0 : positionSeconds;

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
    videoId: (json['video_id'] as num?)?.toInt() ?? 0,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    positionSeconds: (json['position_seconds'] as num?)?.toDouble() ?? 0,
    durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
  );
}

final class WatchRepository {
  const WatchRepository(this._client);
  final ApiClient _client;

  Future<List<VideoType>> fetchVideoTypes() async {
    try {
      final response = await _client.dio.get<List<dynamic>>('video-types/');
      return [
        for (final item in response.data ?? const [])
          VideoType.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WatchVideosPage> fetchVideos({
    int page = 1,
    String search = '',
    int? videoTypeId,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'videos/',
        queryParameters: {
          'page': page,
          'search': search,
          'video_type': ?videoTypeId,
        },
      );
      return WatchVideosPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WatchVideoDetail> fetchVideo(int id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'videos/$id/',
      );
      return WatchVideoDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Signed-in only. Returns `null` when nothing has been saved yet.
  Future<WatchProgress?> fetchProgress(int id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'watch-progress/$id/',
      );
      final data = response.data;
      return data == null ? null : WatchProgress.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  Future<void> saveProgress(
    int id, {
    required double progress,
    required double positionSeconds,
    required double durationSeconds,
  }) async {
    try {
      await _client.dio.put<void>(
        'watch-progress/$id/',
        data: {
          'progress': progress.clamp(0.0, 1.0),
          'position_seconds': positionSeconds,
          'duration_seconds': durationSeconds,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
