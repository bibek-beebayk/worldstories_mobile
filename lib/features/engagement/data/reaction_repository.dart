import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/providers.dart';

final reactionRepositoryProvider = Provider<ReactionRepository>(
  (ref) => ReactionRepository(ref.watch(apiClientProvider)),
);

/// `StoryReaction.reaction_type` values, per the backend's taxonomy.
enum ReactionType {
  loved,
  funny,
  surprising,
  emotional,
  thoughtProvoking;

  String get wireValue => switch (this) {
    ReactionType.loved => 'loved',
    ReactionType.funny => 'funny',
    ReactionType.surprising => 'surprising',
    ReactionType.emotional => 'emotional',
    ReactionType.thoughtProvoking => 'thought_provoking',
  };
}

final class ReactionCount {
  const ReactionCount({
    required this.type,
    required this.label,
    required this.count,
  });
  final String type;
  final String label;
  final int count;
  factory ReactionCount.fromJson(Map<String, dynamic> json) => ReactionCount(
    type: json['type'] as String,
    label: json['label'] as String,
    count: json['count'] as int? ?? 0,
  );
}

final class ReactionSummary {
  const ReactionSummary({
    required this.reactions,
    required this.total,
    required this.myReaction,
  });
  final List<ReactionCount> reactions;
  final int total;
  final String? myReaction;
  factory ReactionSummary.fromJson(Map<String, dynamic> json) =>
      ReactionSummary(
        reactions: (json['reactions'] as List? ?? const [])
            .map(
              (item) => ReactionCount.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        total: json['total'] as int? ?? 0,
        myReaction: json['my_reaction'] as String?,
      );
}

final class ReactionRepository {
  const ReactionRepository(this._client);
  final ApiClient _client;

  Future<ReactionSummary> fetch(String storySlug) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/reactions/',
      );
      return ReactionSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Toggle semantics: sending the same type again removes it, per the API.
  Future<ReactionSummary> toggle(String storySlug, ReactionType type) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        'stories/${Uri.encodeComponent(storySlug)}/reactions/',
        data: {'reaction_type': type.wireValue},
      );
      return ReactionSummary.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
