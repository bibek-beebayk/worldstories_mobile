import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final readAlongRepositoryProvider = Provider<ReadAlongRepository>(
  (ref) => ReadAlongRepository(ref.watch(apiClientProvider)),
);

final class ReadAlongCue {
  const ReadAlongCue({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });
  final double startSeconds;
  final double endSeconds;
  final String text;
  factory ReadAlongCue.fromJson(Map<String, dynamic> json) => ReadAlongCue(
    startSeconds: (json['start_seconds'] as num).toDouble(),
    endSeconds: (json['end_seconds'] as num).toDouble(),
    text: json['text'] as String? ?? '',
  );
}

final class ReadAlongPayload {
  const ReadAlongPayload({
    required this.audioTitle,
    required this.streamUrl,
    required this.durationSeconds,
    required this.cues,
    required this.defaultOffsetSeconds,
    required this.previousAudioSlug,
    required this.nextAudioSlug,
  });
  final String audioTitle;
  final String? streamUrl;
  final double? durationSeconds;
  final List<ReadAlongCue> cues;
  final double defaultOffsetSeconds;
  final String? previousAudioSlug;
  final String? nextAudioSlug;

  factory ReadAlongPayload.fromJson(Map<String, dynamic> json) {
    final audio = Map<String, dynamic>.from(json['audio'] as Map);
    final transcript = Map<String, dynamic>.from(json['transcript'] as Map);
    final navigation = Map<String, dynamic>.from(json['navigation'] as Map);
    return ReadAlongPayload(
      audioTitle: audio['title'] as String? ?? '',
      streamUrl: audio['stream_url'] as String?,
      durationSeconds: (audio['duration_seconds'] as num?)?.toDouble(),
      cues: (transcript['cues'] as List? ?? const [])
          .map(
            (item) =>
                ReadAlongCue.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      defaultOffsetSeconds:
          (transcript['default_offset_seconds'] as num?)?.toDouble() ?? 0,
      previousAudioSlug: navigation['previous_audio_slug'] as String?,
      nextAudioSlug: navigation['next_audio_slug'] as String?,
    );
  }
}

/// Binary search for the last cue whose start has passed `timeSeconds`,
/// returning -1 if that cue has also already ended. Mirrors
/// `findActiveCueIndex` in the web client's `src/lib/readAlongCues.ts` so the
/// two clients highlight identically for the same cue data.
int findActiveCueIndex(List<ReadAlongCue> cues, double timeSeconds) {
  var lo = 0;
  var hi = cues.length - 1;
  var candidate = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (cues[mid].startSeconds <= timeSeconds) {
      candidate = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (candidate == -1) return -1;
  return timeSeconds < cues[candidate].endSeconds ? candidate : -1;
}

final class ReadAlongRepository {
  const ReadAlongRepository(this._client);
  final ApiClient _client;

  Future<ReadAlongPayload> fetch({
    required String storySlug,
    required String audioSlug,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/read-along/${Uri.encodeComponent(audioSlug)}/',
      );
      return ReadAlongPayload.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
