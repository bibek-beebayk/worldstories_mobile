import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../data/journey_repository.dart';
import '../../../core/api_error_view.dart';

final journeyListProvider = FutureProvider<List<Journey>>(
  (ref) => ref.read(journeyRepositoryProvider).fetchList(),
);
final journeyDetailProvider = FutureProvider.family<JourneyDetail, String>(
  (ref, slug) => ref.read(journeyRepositoryProvider).fetchDetail(slug),
);

class JourneysScreen extends ConsumerWidget {
  const JourneysScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Story Journeys')),
    body: ref
        .watch(journeyListProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (journeys) => RefreshIndicator(
            onRefresh: () => ref.refresh(journeyListProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: journeys.length,
              itemBuilder: (context, index) {
                final journey = journeys[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(journey.title),
                    subtitle: Text(journey.description),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          journey.isComplete
                              ? Icons.check_circle
                              : Icons.chevron_right,
                          color: journey.isComplete ? Colors.green : null,
                        ),
                        Text('${journey.completed}/${journey.total}'),
                      ],
                    ),
                    onTap: () => context.push('/journeys/${journey.slug}'),
                  ),
                );
              },
            ),
          ),
        ),
  );
}

class JourneyDetailScreen extends ConsumerWidget {
  const JourneyDetailScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(journeyDetailProvider(slug), (previous, next) {
      if (previous != null) return;
      next.whenData((detail) {
        if (detail.journey.completed == 0) {
          ref
              .read(analyticsServiceProvider)
              .track(
                AnalyticsEventType.journeyStarted,
                metadata: {'journey_slug': slug},
              );
        }
      });
    });
    return Scaffold(
    appBar: AppBar(title: const Text('Journey')),
    body: ref
        .watch(journeyDetailProvider(slug))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (detail) => RefreshIndicator(
            onRefresh: () => ref.refresh(journeyDetailProvider(slug).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  detail.journey.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(detail.journey.description),
                const SizedBox(height: 8),
                Text('${detail.journey.completed}/${detail.journey.total} completed'),
                const Divider(height: 32),
                ...detail.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.completed ? Icons.check_circle : Icons.circle_outlined,
                      color: item.completed ? Colors.green : null,
                    ),
                    title: Text(item.story.title),
                    subtitle: item.story.author == null
                        ? null
                        : Text(item.story.author!),
                    onTap: item.story.slug.isEmpty
                        ? null
                        : () => context.push('/story/${item.story.slug}'),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
  }
}
