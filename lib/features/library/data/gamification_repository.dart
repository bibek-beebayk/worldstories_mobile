import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';
import '../../home/data/home_repository.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>(
  (ref) => GamificationRepository(ref.watch(apiClientProvider)),
);

final class ReadingStreak {
  const ReadingStreak({required this.currentStreak, required this.longestStreak});
  final int currentStreak;
  final int longestStreak;
  factory ReadingStreak.fromJson(Map<String, dynamic> json) => ReadingStreak(
    currentStreak: json['current_streak'] as int? ?? 0,
    longestStreak: json['longest_streak'] as int? ?? 0,
  );
}

final class Achievement {
  const Achievement({
    required this.slug,
    required this.name,
    required this.description,
    required this.icon,
    required this.targetValue,
    required this.progress,
    required this.completed,
  });
  final String slug;
  final String name;
  final String description;
  final String icon;
  final int targetValue;
  final int progress;
  final bool completed;
  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    slug: json['slug'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    icon: json['icon'] as String? ?? '🏆',
    targetValue: json['target_value'] as int? ?? 0,
    progress: json['progress'] as int? ?? 0,
    completed: json['completed'] as bool? ?? false,
  );
}

final class AchievementSummary {
  const AchievementSummary({
    required this.earned,
    required this.total,
    required this.achievements,
  });
  final int earned;
  final int total;
  final List<Achievement> achievements;
  factory AchievementSummary.fromJson(Map<String, dynamic> json) =>
      AchievementSummary(
        earned: json['earned'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        achievements: (json['results'] as List? ?? const [])
            .map(
              (item) =>
                  Achievement.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

/// Mirrors `passport_summary()` in `worldstories_b/apps/stats/passport.py`
/// exactly (read directly, since the API docs defer this shape to source).
final class PassportCountry {
  const PassportCountry({
    required this.code,
    required this.name,
    required this.storiesAvailable,
    required this.storiesCompleted,
    required this.explored,
  });
  final String code;
  final String name;
  final int storiesAvailable;
  final int storiesCompleted;
  final bool explored;
  factory PassportCountry.fromJson(Map<String, dynamic> json) =>
      PassportCountry(
        code: json['code'] as String,
        name: json['name'] as String,
        storiesAvailable: json['stories_available'] as int? ?? 0,
        storiesCompleted: json['stories_completed'] as int? ?? 0,
        explored: json['explored'] as bool? ?? false,
      );
}

final class PassportSummary {
  const PassportSummary({
    required this.countriesExplored,
    required this.countriesAvailable,
    required this.storiesCompleted,
    required this.countries,
  });
  final int countriesExplored;
  final int countriesAvailable;
  final int storiesCompleted;
  final List<PassportCountry> countries;
  factory PassportSummary.fromJson(Map<String, dynamic> json) =>
      PassportSummary(
        countriesExplored: json['countries_explored'] as int? ?? 0,
        countriesAvailable: json['countries_available'] as int? ?? 0,
        storiesCompleted: json['stories_completed'] as int? ?? 0,
        countries: (json['countries'] as List? ?? const [])
            .map(
              (item) => PassportCountry.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}

final class PassportCountryDetail {
  const PassportCountryDetail({
    required this.code,
    required this.name,
    required this.explored,
    required this.storiesAvailable,
    required this.storiesCompleted,
    required this.completed,
    required this.continueExploring,
  });
  final String code;
  final String name;
  final bool explored;
  final int storiesAvailable;
  final int storiesCompleted;
  final List<StorySummary> completed;
  final List<StorySummary> continueExploring;
  factory PassportCountryDetail.fromJson(Map<String, dynamic> json) =>
      PassportCountryDetail(
        code: json['code'] as String,
        name: json['name'] as String,
        explored: json['explored'] as bool? ?? false,
        storiesAvailable: json['stories_available'] as int? ?? 0,
        storiesCompleted: json['stories_completed'] as int? ?? 0,
        completed: (json['completed'] as List? ?? const [])
            .map(
              (item) =>
                  StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        continueExploring: (json['continue_exploring'] as List? ?? const [])
            .map(
              (item) =>
                  StorySummary.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

final class WeeklyRecap {
  const WeeklyRecap({
    required this.storiesCompleted,
    required this.minutesRead,
    required this.countriesExplored,
    required this.journeysCompleted,
    required this.currentStreak,
    required this.favouriteGenre,
    required this.hasActivity,
  });
  final int storiesCompleted;
  final int minutesRead;
  final int countriesExplored;
  final int journeysCompleted;
  final int currentStreak;
  final String? favouriteGenre;
  final bool hasActivity;
  factory WeeklyRecap.fromJson(Map<String, dynamic> json) => WeeklyRecap(
    storiesCompleted: json['stories_completed'] as int? ?? 0,
    minutesRead: json['minutes_read'] as int? ?? 0,
    countriesExplored: json['countries_explored'] as int? ?? 0,
    journeysCompleted: json['journeys_completed'] as int? ?? 0,
    currentStreak: json['current_streak'] as int? ?? 0,
    favouriteGenre: json['favourite_genre'] as String?,
    hasActivity: json['has_activity'] as bool? ?? false,
  );
}

final class ProfileInsights {
  const ProfileInsights({
    required this.titlesStarted,
    required this.titlesCompleted,
    required this.activeDays30,
    required this.favoriteGenre,
    required this.totalReadingMinutes,
    required this.countriesExplored,
  });
  final int titlesStarted;
  final int titlesCompleted;
  final int activeDays30;
  final String? favoriteGenre;
  final int totalReadingMinutes;
  final int countriesExplored;
  factory ProfileInsights.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map);
    return ProfileInsights(
      titlesStarted: summary['titles_started'] as int? ?? 0,
      titlesCompleted: summary['titles_completed'] as int? ?? 0,
      activeDays30: summary['active_days_30'] as int? ?? 0,
      favoriteGenre: summary['favorite_genre'] as String?,
      totalReadingMinutes: summary['total_reading_minutes'] as int? ?? 0,
      countriesExplored: summary['countries_explored'] as int? ?? 0,
    );
  }
}

final class GamificationRepository {
  const GamificationRepository(this._client);
  final ApiClient _client;

  Future<ReadingStreak> fetchStreak() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/reading-streak/',
      );
      return ReadingStreak.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AchievementSummary> fetchAchievements() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/achievements/',
      );
      return AchievementSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PassportSummary> fetchPassport() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/story-passport/',
      );
      return PassportSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PassportCountryDetail> fetchPassportCountry(String countryCode) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/story-passport/${Uri.encodeComponent(countryCode)}/',
      );
      return PassportCountryDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<WeeklyRecap> fetchWeeklyRecap() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/weekly-recap/',
      );
      return WeeklyRecap.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ProfileInsights> fetchProfileInsights() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/profile-insights/',
      );
      return ProfileInsights.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
