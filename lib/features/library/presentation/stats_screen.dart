import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_exception.dart';
import '../data/gamification_repository.dart';

final readingStreakProvider = FutureProvider<ReadingStreak>(
  (ref) => ref.read(gamificationRepositoryProvider).fetchStreak(),
);
final achievementSummaryProvider = FutureProvider<AchievementSummary>(
  (ref) => ref.read(gamificationRepositoryProvider).fetchAchievements(),
);
final weeklyRecapProvider = FutureProvider<WeeklyRecap>(
  (ref) => ref.read(gamificationRepositoryProvider).fetchWeeklyRecap(),
);
final profileInsightsProvider = FutureProvider<ProfileInsights>(
  (ref) => ref.read(gamificationRepositoryProvider).fetchProfileInsights(),
);

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Your reading stats')),
    body: RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(readingStreakProvider.future),
        ref.refresh(achievementSummaryProvider.future),
        ref.refresh(weeklyRecapProvider.future),
        ref.refresh(profileInsightsProvider.future),
      ]),
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.public),
          title: const Text('Story Passport'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/passport'),
        ),
        ListTile(
          leading: const Icon(Icons.route),
          title: const Text('Journeys'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/journeys'),
        ),
        const Divider(height: 32),
        Text('Streak', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ref
            .watch(readingStreakProvider)
            .when(
              loading: () => const _InlineLoading(),
              error: (error, _) => Text(apiErrorMessage(error)),
              data: (streak) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatTile(label: 'Current streak', value: '${streak.currentStreak}'),
                  _StatTile(label: 'Longest streak', value: '${streak.longestStreak}'),
                ],
              ),
            ),
        const Divider(height: 32),
        Text('This week', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ref
            .watch(weeklyRecapProvider)
            .when(
              loading: () => const _InlineLoading(),
              error: (error, _) => Text(apiErrorMessage(error)),
              data: (recap) => recap.hasActivity
                  ? Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _StatTile(label: 'Stories finished', value: '${recap.storiesCompleted}'),
                        _StatTile(label: 'Minutes read', value: '${recap.minutesRead}'),
                        _StatTile(label: 'Countries', value: '${recap.countriesExplored}'),
                        _StatTile(label: 'Journeys', value: '${recap.journeysCompleted}'),
                        if (recap.favouriteGenre != null)
                          _StatTile(label: 'Favorite genre', value: recap.favouriteGenre!),
                      ],
                    )
                  : const Text('No activity yet this week.'),
            ),
        const Divider(height: 32),
        Text('Overall', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ref
            .watch(profileInsightsProvider)
            .when(
              loading: () => const _InlineLoading(),
              error: (error, _) => Text(apiErrorMessage(error)),
              data: (insights) => Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _StatTile(label: 'Titles started', value: '${insights.titlesStarted}'),
                  _StatTile(label: 'Titles completed', value: '${insights.titlesCompleted}'),
                  _StatTile(label: 'Active days (30d)', value: '${insights.activeDays30}'),
                  _StatTile(
                    label: 'Reading minutes',
                    value: '${insights.totalReadingMinutes}',
                  ),
                  _StatTile(label: 'Countries', value: '${insights.countriesExplored}'),
                  if (insights.favoriteGenre != null)
                    _StatTile(label: 'Favorite genre', value: insights.favoriteGenre!),
                ],
              ),
            ),
        const Divider(height: 32),
        Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ref
            .watch(achievementSummaryProvider)
            .when(
              loading: () => const _InlineLoading(),
              error: (error, _) => Text(apiErrorMessage(error)),
              data: (summary) => Column(
                children: [
                  Text('${summary.earned} of ${summary.total} earned'),
                  const SizedBox(height: 12),
                  ...summary.achievements.map(
                    (achievement) => ListTile(
                      leading: Text(
                        achievement.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(achievement.name),
                      subtitle: Text(achievement.description),
                      trailing: achievement.completed
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : Text(
                              '${achievement.progress}/${achievement.targetValue}',
                            ),
                    ),
                  ),
                ],
              ),
            ),
      ],
      ),
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 40,
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}
