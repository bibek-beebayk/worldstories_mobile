import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/analytics_repository.dart';

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref.watch(analyticsRepositoryProvider)),
);

/// Owns the two identifiers every analytics event needs
/// (`visitor_id`/`session_id`, per API_REFERENCE.md §5) and exposes a single
/// `track()` for the rest of the app — callers never touch
/// `AnalyticsRepository` or generate an `event_id` themselves.
///
/// `visitor_id` is a UUID persisted in `SharedPreferences`, generated once
/// and reused for the device's lifetime. `session_id` is a UUID generated
/// fresh each app launch (held only in memory) — "session" here means "this
/// run of the app", matching how the equivalent web client scopes a session
/// to one browser tab's lifetime rather than something that needs its own
/// expiry logic.
final class AnalyticsService {
  AnalyticsService(this._repository);
  final AnalyticsRepository _repository;
  static const _visitorIdKey = 'analytics_visitor_id';
  static const _uuid = Uuid();

  String? _visitorId;
  final String _sessionId = _uuid.v4();

  Future<String> _resolveVisitorId() async {
    final cached = _visitorId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var visitorId = prefs.getString(_visitorIdKey);
    if (visitorId == null) {
      visitorId = _uuid.v4();
      await prefs.setString(_visitorIdKey, visitorId);
    }
    _visitorId = visitorId;
    return visitorId;
  }

  /// Fire-and-forget: never awaited by callers, never throws, never retried.
  void track(
    AnalyticsEventType eventType, {
    String? storySlug,
    String? blogSlug,
    double? durationSeconds,
    double? value,
    Map<String, dynamic>? metadata,
  }) {
    unawaited(_send(
      eventType,
      storySlug: storySlug,
      blogSlug: blogSlug,
      durationSeconds: durationSeconds,
      value: value,
      metadata: metadata,
    ));
  }

  Future<void> _send(
    AnalyticsEventType eventType, {
    String? storySlug,
    String? blogSlug,
    double? durationSeconds,
    double? value,
    Map<String, dynamic>? metadata,
  }) async {
    final visitorId = await _resolveVisitorId();
    await _repository.send(
      eventId: _uuid.v4(),
      eventType: eventType,
      visitorId: visitorId,
      sessionId: _sessionId,
      storySlug: storySlug,
      blogSlug: blogSlug,
      durationSeconds: durationSeconds,
      value: value,
      metadata: metadata,
    );
  }
}
