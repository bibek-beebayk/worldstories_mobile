import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../data/story_recommendations_repository.dart';
import '../../../core/api_error_view.dart';

final completionDataProvider = FutureProvider.family<CompletionScreenData, String>(
  (ref, storySlug) =>
      ref.read(storyRecommendationsRepositoryProvider).completion(storySlug),
);

class CompletionScreen extends ConsumerWidget {
  const CompletionScreen({super.key, required this.storySlug});
  final String storySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Story completed')),
    body: ref
        .watch(completionDataProvider(storySlug))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (data) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                Icons.emoji_events,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'You finished "${data.storyTitle}"',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (data.countryName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'A story from ${data.countryName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 28),
              for (final section in data.sections) ...[
                Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...section.stories.map(
                  (story) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_stories),
                    title: Text(story.title),
                    subtitle: story.author == null
                        ? null
                        : Text(story.author!),
                    onTap: story.slug.isEmpty
                        ? null
                        : () {
                            ref
                                .read(analyticsServiceProvider)
                                .track(
                                  AnalyticsEventType.nextStoryClicked,
                                  storySlug: storySlug,
                                  metadata: {'next_story_slug': story.slug},
                                );
                            context.pushReplacement('/story/${story.slug}');
                          },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
  );
}
