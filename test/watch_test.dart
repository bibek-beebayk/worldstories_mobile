import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/watch/data/watch_repository.dart';

Map<String, dynamic> _video(int id, {Object? story, Object? type, Object? dur}) =>
    {
      'id': id,
      'title': 'Video $id',
      'slug': 'video-$id',
      'youtube_id': 'yt$id',
      'duration_seconds': dur,
      'aspect_ratio': id.isEven ? '9:16' : '16:9',
      'thumbnail': 'https://img/$id.jpg',
      'story': story,
      'video_type': type,
    };

void main() {
  test('parses paginated videos incl. null story, type and duration', () {
    final page = WatchVideosPage.fromJson({
      'pagination': {'count': 5, 'page': 1, 'pages': 2, 'size': 3},
      'results': [
        _video(
          1,
          story: {'id': 9, 'title': 'A Story', 'slug': 'a-story'},
          type: {'id': 2, 'name': 'Animated'},
          dur: 125,
        ),
        _video(2),
      ],
    });
    expect(page.count, 5);
    expect(page.hasMore, isTrue);
    final first = page.videos.first;
    expect(first.story?.slug, 'a-story');
    expect(first.videoType?.name, 'Animated');
    expect(first.durationSeconds, 125);
    expect(first.isPortrait, isFalse);
    final second = page.videos.last;
    expect(second.story, isNull);
    expect(second.videoType, isNull);
    expect(second.durationSeconds, isNull);
    expect(second.isPortrait, isTrue);
  });

  test('last page has no more', () {
    final page = WatchVideosPage.fromJson({
      'pagination': {'count': 1, 'page': 2, 'pages': 2, 'size': 1},
      'results': <dynamic>[],
    });
    expect(page.hasMore, isFalse);
  });

  test('parses detail with suggested', () {
    final detail = WatchVideoDetail.fromJson({
      ..._video(3),
      'suggested': [_video(4), _video(5)],
    });
    expect(detail.video.id, 3);
    expect(detail.suggested.map((v) => v.id), [4, 5]);
    expect(WatchVideoDetail.fromJson(_video(6)).suggested, isEmpty);
  });

  test('progress start position ignores finished videos', () {
    WatchProgress p(double progress) => WatchProgress.fromJson({
      'video_id': 1,
      'progress': progress,
      'position_seconds': 80,
      'duration_seconds': 100,
    });
    expect(p(0.8).startSeconds, 80);
    expect(p(0.995).startSeconds, 0);
  });

  test('formats durations', () {
    expect(formatVideoDuration(null), '');
    expect(formatVideoDuration(0), '');
    expect(formatVideoDuration(5), '0:05');
    expect(formatVideoDuration(125), '2:05');
    expect(formatVideoDuration(3600), '1:00:00');
    expect(formatVideoDuration(3725), '1:02:05');
  });
}
