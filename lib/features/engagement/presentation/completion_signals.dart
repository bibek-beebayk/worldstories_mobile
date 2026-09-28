import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';

/// Shared handling for the `story_completed`/`unlocked_country`/
/// `unlocked_achievements` signals that `reading-progress`, `audio-progress`,
/// `video-progress`, and `file-reading-progress` PUT responses carry (see
/// API_REFERENCE.md §5) — every reader/player screen that saves progress
/// against one of those endpoints should route its result through this
/// instead of building its own snackbar, so the completion screen is reached
/// consistently everywhere a story can actually be finished, and the
/// corresponding analytics beacons fire from one place instead of five.
void handleCompletionSignals(
  BuildContext context,
  WidgetRef ref,
  String storySlug, {
  required bool storyCompleted,
  String? unlockedCountry,
  required List<Map<String, dynamic>> unlockedAchievements,
}) {
  final analytics = ref.read(analyticsServiceProvider);
  final messages = <String>[
    if (unlockedCountry != null) 'Country unlocked: $unlockedCountry',
    if (unlockedAchievements.isNotEmpty)
      '${unlockedAchievements.length} achievement unlocked',
  ];
  if (unlockedCountry != null) {
    analytics.track(
      AnalyticsEventType.countryUnlocked,
      storySlug: storySlug,
      metadata: {'country': unlockedCountry},
    );
  }
  for (final achievement in unlockedAchievements) {
    analytics.track(
      AnalyticsEventType.achievementUnlocked,
      storySlug: storySlug,
      metadata: achievement,
    );
  }
  if (messages.isNotEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(messages.join(' • '))));
  }
  if (storyCompleted) {
    analytics.track(AnalyticsEventType.storyCompleted, storySlug: storySlug);
    context.push('/story/$storySlug/completion');
  }
}
