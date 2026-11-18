import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/providers.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(apiClientProvider)),
);

/// `AnalyticsEventWriteSerializer.event_type` enum, per API_REFERENCE.md §5.
enum AnalyticsEventType {
  visit,
  adImpression,
  readingSession,
  listeningSession,
  watchingSession,
  completion,
  download,
  readAlongCueSeek,
  readAlongFollowToggle,
  quickReadOpened,
  quickReadCompleted,
  quickReadFullStoryClicked,
  storyStarted,
  storyResumed,
  storyProgressed,
  storyCompleted,
  nextStoryClicked,
  countryUnlocked,
  passportViewed,
  achievementUnlocked,
  journeyStarted,
  journeyCompleted,
  reactionAdded,
  surpriseMeClicked,
  moodSelected,
  dailyStoryViewed,
  dailyStoryStarted,
  dailyStoryCompleted;

  String get wireValue => switch (this) {
    AnalyticsEventType.visit => 'visit',
    AnalyticsEventType.adImpression => 'ad_impression',
    AnalyticsEventType.readingSession => 'reading_session',
    AnalyticsEventType.listeningSession => 'listening_session',
    AnalyticsEventType.watchingSession => 'watching_session',
    AnalyticsEventType.completion => 'completion',
    AnalyticsEventType.download => 'download',
    AnalyticsEventType.readAlongCueSeek => 'read_along_cue_seek',
    AnalyticsEventType.readAlongFollowToggle => 'read_along_follow_toggle',
    AnalyticsEventType.quickReadOpened => 'quick_read_opened',
    AnalyticsEventType.quickReadCompleted => 'quick_read_completed',
    AnalyticsEventType.quickReadFullStoryClicked =>
      'quick_read_full_story_clicked',
    AnalyticsEventType.storyStarted => 'story_started',
    AnalyticsEventType.storyResumed => 'story_resumed',
    AnalyticsEventType.storyProgressed => 'story_progressed',
    AnalyticsEventType.storyCompleted => 'story_completed',
    AnalyticsEventType.nextStoryClicked => 'next_story_clicked',
    AnalyticsEventType.countryUnlocked => 'country_unlocked',
    AnalyticsEventType.passportViewed => 'passport_viewed',
    AnalyticsEventType.achievementUnlocked => 'achievement_unlocked',
    AnalyticsEventType.journeyStarted => 'journey_started',
    AnalyticsEventType.journeyCompleted => 'journey_completed',
    AnalyticsEventType.reactionAdded => 'reaction_added',
    AnalyticsEventType.surpriseMeClicked => 'surprise_me_clicked',
    AnalyticsEventType.moodSelected => 'mood_selected',
    AnalyticsEventType.dailyStoryViewed => 'daily_story_viewed',
    AnalyticsEventType.dailyStoryStarted => 'daily_story_started',
    AnalyticsEventType.dailyStoryCompleted => 'daily_story_completed',
  };
}

final class AnalyticsRepository {
  const AnalyticsRepository(this._client);
  final ApiClient _client;

  /// Fire-and-forget by design — callers must never surface a failure here
  /// to the UI or retry it. A dropped analytics beacon is not worth a user-
  /// visible error, and a 202 (bot/superuser traffic, silently accepted) is
  /// not distinguishable from — nor worse than — a 201 for this purpose.
  Future<void> send({
    required String eventId,
    required AnalyticsEventType eventType,
    required String visitorId,
    String? sessionId,
    String? storySlug,
    String? blogSlug,
    int? videoId,
    double? durationSeconds,
    double? value,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.dio.post<void>(
        'analytics/events/',
        data: {
          'event_id': eventId,
          'event_type': eventType.wireValue,
          'visitor_id': visitorId,
          'session_id': ?sessionId,
          'story_slug': ?storySlug,
          'blog_slug': ?blogSlug,
          'video_id': ?videoId,
          'duration_seconds': ?durationSeconds,
          'value': ?value,
          'metadata': ?(metadata == null ? null : jsonEncode(metadata)),
        },
      );
    } on DioException {
      // Best-effort; analytics beacons are never retried or surfaced.
    }
  }
}
