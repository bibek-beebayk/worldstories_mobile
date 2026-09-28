import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/data/home_repository.dart';
import '../data/library_repository.dart';
import '../../../core/api_error_view.dart';

const _tabs = <(String label, String endpoint)>[
  ('Reading', 'continue-reading'),
  ('Listening', 'continue-listening'),
  ('Watching', 'continue-watching'),
  ('Completed', 'completed-reading'),
  ('History', 'reading-history'),
  ('Favorites', 'favorites'),
  ('Reviews', 'reviews'),
];

final libraryPageProvider = FutureProvider.family<LibraryPage, String>(
  (ref, endpoint) => ref.read(libraryRepositoryProvider).fetch(endpoint),
);
final recommendationsProvider = FutureProvider<List<StorySummary>>(
  (ref) => ref.read(libraryRepositoryProvider).fetchRecommendations(),
);

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _tabs.length + 1,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            for (final tab in _tabs) Tab(text: tab.$1),
            const Tab(text: 'For You'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          for (final tab in _tabs) _LibraryTab(endpoint: tab.$2),
          const _RecommendationsTab(),
        ],
      ),
    ),
  );
}

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab({required this.endpoint});
  final String endpoint;

  String? _subtitle(LibraryItem item) {
    switch (endpoint) {
      case 'continue-reading':
      case 'completed-reading':
        final parts = <String>[
          if (item.chapterTitle != null) item.chapterTitle!,
          if (item.overallProgress != null)
            '${(item.overallProgress! * 100).round()}% read',
          if (item.remainingMinutes != null) '${item.remainingMinutes} min left',
        ];
        return parts.isEmpty ? null : parts.join(' • ');
      case 'continue-listening':
        final parts = <String>[
          if (item.audioTitle != null) item.audioTitle!,
          if (item.overallProgress != null)
            '${(item.overallProgress! * 100).round()}% listened',
        ];
        return parts.isEmpty ? null : parts.join(' • ');
      case 'continue-watching':
        final parts = <String>[
          if (item.videoTitle != null) item.videoTitle!,
          if (item.overallProgress != null)
            '${(item.overallProgress! * 100).round()}% watched',
        ];
        return parts.isEmpty ? null : parts.join(' • ');
      case 'reading-history':
        if (item.completed == true) return 'Completed';
        if (item.historyProgress != null) {
          return '${(item.historyProgress! * 100).round()}% read';
        }
        return null;
      case 'reviews':
        final stars = item.rating == null ? '' : '★' * item.rating!;
        return [
          stars,
          if (item.comment != null && item.comment!.isNotEmpty) item.comment,
        ].where((s) => s != null && s.isNotEmpty).join(' — ');
      default:
        return item.story.storyType;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(libraryPageProvider(endpoint))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ApiErrorView(error: error),
        data: (page) => RefreshIndicator(
          onRefresh: () => ref.refresh(libraryPageProvider(endpoint).future),
          child: page.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(child: Text('Nothing here yet.')),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: page.items.length,
                  itemBuilder: (context, index) {
                    final item = page.items[index];
                    final subtitle = _subtitle(item);
                    return ListTile(
                      leading: const Icon(Icons.auto_stories),
                      title: Text(item.story.title),
                      subtitle: subtitle == null ? null : Text(subtitle),
                      onTap: item.story.slug.isEmpty
                          ? null
                          : () => context.push('/story/${item.story.slug}'),
                    );
                  },
                ),
        ),
      );
}

class _RecommendationsTab extends ConsumerWidget {
  const _RecommendationsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(recommendationsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ApiErrorView(error: error),
        data: (stories) => RefreshIndicator(
          onRefresh: () => ref.refresh(recommendationsProvider.future),
          child: stories.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(child: Text('No recommendations yet.')),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: stories.length,
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    return ListTile(
                      leading: const Icon(Icons.auto_stories),
                      title: Text(story.title),
                      subtitle:
                          story.author == null ? null : Text(story.author!),
                      onTap: story.slug.isEmpty
                          ? null
                          : () => context.push('/story/${story.slug}'),
                    );
                  },
                ),
        ),
      );
}
