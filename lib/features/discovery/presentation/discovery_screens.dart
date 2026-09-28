import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/cached_app_image.dart';
import '../../../core/api_error_view.dart';
import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_screen.dart' show showSurpriseStoryDialog;
import '../../library/data/mood_repository.dart';
import '../data/discovery_repository.dart';
import 'interactive_story_map.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(apiClientProvider)),
);
final discoverProvider = FutureProvider<DiscoverData>(
  (ref) => ref.watch(discoveryRepositoryProvider).discover(),
);
final trendingProvider = FutureProvider<TrendingData>(
  (ref) => ref.watch(discoveryRepositoryProvider).trending(),
);
final storyMapProvider = FutureProvider<StoryMapData>(
  (ref) => ref.watch(discoveryRepositoryProvider).storyMap(),
);
final discoverMoodsProvider = FutureProvider<List<Mood>>(
  (ref) => ref.watch(moodRepositoryProvider).fetchList(),
);
final _moodStoriesRepositoryProvider = Provider<CatalogueRepository>(
  (ref) => CatalogueRepository(ref.watch(apiClientProvider)),
);

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(discoverMoodsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            onPressed: () => context.push('/trending'),
            icon: const Icon(Icons.trending_up),
            tooltip: 'Trending',
          ),
          IconButton(
            onPressed: () => context.push('/story-map'),
            icon: const Icon(Icons.public),
            tooltip: 'Story Map',
          ),
        ],
      ),
      body: ref
          .watch(discoverProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ApiErrorView(error: error),
            data: (data) => RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.refresh(discoverProvider.future),
                  ref.refresh(discoverMoodsProvider.future),
                ]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _SurpriseMeCard(
                    onTap: () async {
                      ref
                          .read(analyticsServiceProvider)
                          .track(AnalyticsEventType.surpriseMeClicked);
                      await showSurpriseStoryDialog(context);
                    },
                  ),
                  const SizedBox(height: 28),
                  _MoodSection(moods: moods),
                  const SizedBox(height: 28),
                  Text(
                    'Browse genres',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.genres
                        .map(
                          (item) => _FacetTile(
                            facet: item,
                            onTap: () => _showFilteredStories(
                              context,
                              title: item.name,
                              leading: const Icon(
                                Icons.auto_stories_outlined,
                                color: AppTheme.primary,
                              ),
                              queryForPage: (page) => CatalogueQuery(
                                page: page,
                                genreIds: {item.id},
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  const _StoryMapPromo(),
                  const SizedBox(height: 24),
                  Text(
                    'Browse by Story Type',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.3,
                        ),
                    itemCount: data.storyTypes.length,
                    itemBuilder: (context, index) {
                      final item = data.storyTypes[index];
                      return _DiscoveryFacetCard(
                        facet: item,
                        colorIndex: index,
                        onTap: () => _showFilteredStories(
                          context,
                          title: item.name,
                          leading: const Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.primary,
                          ),
                          queryForPage: (page) => CatalogueQuery(
                            page: page,
                            storyType: item.id.toString(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Browse categories',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.3,
                        ),
                    itemCount: data.categories.length,
                    itemBuilder: (context, index) {
                      final item = data.categories[index];
                      return _DiscoveryFacetCard(
                        facet: item,
                        colorIndex: index,
                        onTap: () => _showFilteredStories(
                          context,
                          title: item.name,
                          leading: const Icon(
                            Icons.category_outlined,
                            color: AppTheme.primary,
                          ),
                          queryForPage: (page) => CatalogueQuery(
                            page: page,
                            categoryIds: {item.id},
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _StoryJourneyPromo(),
                  _StoryList(
                    title: 'Most viewed',
                    stories: data.mostViewed,
                    metric: _StoryListMetric.views,
                  ),
                  _StoryList(
                    title: 'Highest rated',
                    stories: data.highestRated,
                    metric: _StoryListMetric.rating,
                  ),
                  _StoryList(title: 'New releases', stories: data.newReleases),
                  _StoryList(title: 'Hidden gems', stories: data.hiddenGems),
                ],
              ),
            ),
          ),
    );
  }
}

class _SurpriseMeCard extends StatelessWidget {
  const _SurpriseMeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.heroDark, AppTheme.heroGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surprise Me',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Let us choose your next story.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StoryMapPromo extends StatelessWidget {
  const _StoryMapPromo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFE6F7F8), Color(0xFFEEF2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFFB9E4E7)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF0E7490),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.public, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find Stories From Different Countries',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push('/story-map'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7490),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text('View Story Map'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StoryJourneyPromo extends StatelessWidget {
  const _StoryJourneyPromo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF3E8FF), Color(0xFFEEF2FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFFD8B4FE)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF7C3AED),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.route, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Follow a Curated Story Journey',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push('/journeys'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.route, size: 17),
                label: const Text('Explore Journeys'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryFacetCard extends StatelessWidget {
  const _DiscoveryFacetCard({
    required this.facet,
    required this.colorIndex,
    required this.onTap,
  });

  final NamedFacet facet;
  final int colorIndex;
  final VoidCallback onTap;

  static const palettes = [
    (Color(0xFFEFF6FF), Color(0xFF93C5FD), Color(0xFF1E3A8A)),
    (Color(0xFFF5F3FF), Color(0xFFC4B5FD), Color(0xFF5B21B6)),
    (Color(0xFFECFDF5), Color(0xFF6EE7B7), Color(0xFF065F46)),
    (Color(0xFFFFF7ED), Color(0xFFFDBA74), Color(0xFF9A3412)),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = palettes[colorIndex % palettes.length];
    return Material(
      color: palette.$1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: palette.$2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                facet.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.$3,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${facet.count} stories',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.$3.withValues(alpha: 0.72),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacetTile extends StatelessWidget {
  const _FacetTile({required this.facet, required this.onTap});

  final NamedFacet facet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.primary.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              facet.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${facet.count}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MoodSection extends ConsumerWidget {
  const _MoodSection({required this.moods});

  final AsyncValue<List<Mood>> moods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMoods = moods.value;
    if (moods.hasError || allMoods?.isEmpty == true) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Read by Mood',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Pick a feeling rather than a genre.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (allMoods == null)
            const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: allMoods.length,
              itemBuilder: (context, index) {
                final mood = allMoods[index];
                return _MoodCard(
                  mood: mood,
                  onTap: () {
                    ref
                        .read(analyticsServiceProvider)
                        .track(
                          AnalyticsEventType.moodSelected,
                          metadata: {'mood': mood.slug},
                        );
                    _showFilteredStories(
                      context,
                      title: mood.name,
                      leading: _MoodGlyph(mood: mood, size: 25),
                      queryForPage: (page) =>
                          CatalogueQuery(page: page, moodSlugs: {mood.slug}),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

typedef _CatalogueQueryBuilder = CatalogueQuery Function(int page);

Future<void> _showFilteredStories(
  BuildContext context, {
  required String title,
  required Widget leading,
  required _CatalogueQueryBuilder queryForPage,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  builder: (context) => _FilteredStoriesModal(
    title: title,
    leading: leading,
    queryForPage: queryForPage,
  ),
);

class _FilteredStoriesModal extends ConsumerStatefulWidget {
  const _FilteredStoriesModal({
    required this.title,
    required this.leading,
    required this.queryForPage,
  });

  final String title;
  final Widget leading;
  final _CatalogueQueryBuilder queryForPage;

  @override
  ConsumerState<_FilteredStoriesModal> createState() =>
      _FilteredStoriesModalState();
}

class _FilteredStoriesModalState extends ConsumerState<_FilteredStoriesModal> {
  final scrollController = ScrollController();
  final stories = <StorySummary>[];
  bool initialLoading = true;
  bool loadingMore = false;
  Object? initialError;
  Object? loadMoreError;
  int page = 0;
  int pages = 1;
  int totalCount = 0;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_handleScroll);
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (scrollController.position.extentAfter < 400) _loadMore();
  }

  CatalogueQuery _query(int requestedPage) =>
      widget.queryForPage(requestedPage);

  Future<void> _refresh() async {
    if (!mounted) return;
    final requestGeneration = ++generation;
    setState(() {
      initialLoading = true;
      loadingMore = false;
      initialError = null;
      loadMoreError = null;
      page = 0;
      pages = 1;
      totalCount = 0;
      stories.clear();
    });
    try {
      final result = await ref
          .read(_moodStoriesRepositoryProvider)
          .fetch(_query(1));
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        stories.addAll(result.stories);
        page = result.page;
        pages = result.pages;
        totalCount = result.count;
        initialLoading = false;
      });
      _continueIfNeeded();
    } catch (error) {
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        initialError = error;
        initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (initialLoading || loadingMore || page >= pages) return;
    final requestGeneration = generation;
    final nextPage = page + 1;
    setState(() {
      loadingMore = true;
      loadMoreError = null;
    });
    try {
      final result = await ref
          .read(_moodStoriesRepositoryProvider)
          .fetch(_query(nextPage));
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        stories.addAll(result.stories);
        page = result.page;
        pages = result.pages;
        totalCount = result.count;
        loadingMore = false;
      });
      _continueIfNeeded();
    } catch (error) {
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        loadMoreError = error;
        loadingMore = false;
      });
    }
  }

  void _continueIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          scrollController.hasClients &&
          scrollController.position.extentAfter < 400) {
        _loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.92,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      initialLoading
                          ? 'Finding stories…'
                          : '$totalCount stories',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _body(context)),
      ],
    ),
  );

  Widget _body(BuildContext context) {
    if (initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (initialError != null) {
      return ApiErrorView(error: initialError!, onRetry: _refresh);
    }
    if (stories.isEmpty) {
      return const Center(child: Text('No stories found.'));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            sliver: SliverGrid.builder(
              itemCount: stories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
                childAspectRatio: 0.54,
              ),
              itemBuilder: (context, index) =>
                  _FilteredStoryCard(story: stories[index]),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilteredStoriesLoadMoreFooter(
              loading: loadingMore,
              failed: loadMoreError != null,
              hasMore: page < pages,
              onRetry: _loadMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredStoryCard extends StatelessWidget {
  const _FilteredStoryCard({required this.story});

  final StorySummary story;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/story/${story.slug}');
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: story.coverImage == null || story.coverImage!.isEmpty
                ? const ColoredBox(
                    color: AppTheme.muted,
                    child: Icon(Icons.auto_stories),
                  )
                : CachedAppImage(
                    imageUrl: story.coverImage!,
                    fit: BoxFit.cover,
                    error: (_) => const ColoredBox(
                      color: AppTheme.muted,
                      child: Icon(Icons.auto_stories),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          story.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 12),
        ),
      ],
    ),
  );
}

class _FilteredStoriesLoadMoreFooter extends StatelessWidget {
  const _FilteredStoriesLoadMoreFooter({
    required this.loading,
    required this.failed,
    required this.hasMore,
    required this.onRetry,
  });

  final bool loading;
  final bool failed;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      );
    }
    return SizedBox(height: hasMore ? 48 : 20);
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.mood, required this.onTap});

  final Mood mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _moodPalette(mood.slug);
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MoodGlyph(mood: mood, size: 23, color: palette.foreground),
              const SizedBox(height: 5),
              Text(
                mood.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.foreground,
                  fontSize: 12,
                ),
              ),
              Text(
                '${mood.storiesCount} stories',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.foreground.withValues(alpha: 0.72),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodGlyph extends StatelessWidget {
  const _MoodGlyph({required this.mood, required this.size, this.color});

  final Mood mood;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => mood.slug == 'emotional'
      ? Icon(
          Icons.sentiment_dissatisfied_rounded,
          size: size,
          color: color ?? Theme.of(context).colorScheme.primary,
        )
      : Text(mood.icon, style: TextStyle(fontSize: size));
}

class _MoodPalette {
  const _MoodPalette(this.background, this.border, this.foreground);

  final Color background;
  final Color border;
  final Color foreground;
}

_MoodPalette _moodPalette(String slug) => switch (slug) {
  'funny' => const _MoodPalette(
    Color(0xFFFFF4CC),
    Color(0xFFF59E0B),
    Color(0xFF92400E),
  ),
  'scary' => const _MoodPalette(
    Color(0xFFFFE4E6),
    Color(0xFFE11D48),
    Color(0xFF9F1239),
  ),
  'magical' => const _MoodPalette(
    Color(0xFFF3E8FF),
    Color(0xFF9333EA),
    Color(0xFF6B21A8),
  ),
  'comforting' => const _MoodPalette(
    Color(0xFFDFF7ED),
    Color(0xFF0D9488),
    Color(0xFF115E59),
  ),
  'emotional' => const _MoodPalette(
    Color(0xFFFFE4E6),
    Color(0xFFFB7185),
    Color(0xFF9F1239),
  ),
  'adventurous' => const _MoodPalette(
    Color(0xFFFFEDD5),
    Color(0xFFEA580C),
    Color(0xFF9A3412),
  ),
  'mysterious' => const _MoodPalette(
    Color(0xFFE0E7FF),
    Color(0xFF4F46E5),
    Color(0xFF3730A3),
  ),
  'inspiring' => const _MoodPalette(
    Color(0xFFFEF9C3),
    Color(0xFFCA8A04),
    Color(0xFF854D0E),
  ),
  'thought-provoking' => const _MoodPalette(
    Color(0xFFCFFAFE),
    Color(0xFF0891B2),
    Color(0xFF155E75),
  ),
  'romantic' => const _MoodPalette(
    Color(0xFFFCE7F3),
    Color(0xFFEC4899),
    Color(0xFF9D174D),
  ),
  _ => const _MoodPalette(
    Color(0xFFF4F1F3),
    Color(0xFFC7B9C2),
    AppTheme.foreground,
  ),
};

class TrendingScreen extends ConsumerWidget {
  const TrendingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Trending')),
    body: ref
        .watch(trendingProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.refresh(trendingProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _StoryList(
                  title: 'Most viewed',
                  stories: data.mostViewed,
                  metric: _StoryListMetric.views,
                ),
                _StoryList(
                  title: 'Highest rated',
                  stories: data.highestRated,
                  metric: _StoryListMetric.rating,
                ),
                _StoryList(
                  title: 'Most favorited',
                  stories: data.mostFavorited,
                ),
                _StoryList(
                  title: 'Most discussed',
                  stories: data.mostDiscussed,
                ),
              ],
            ),
          ),
        ),
  );
}

class StoryMapScreen extends ConsumerWidget {
  const StoryMapScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Story Map'),
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(storyMapProvider),
          tooltip: 'Refresh map',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ref
        .watch(storyMapProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (data) => InteractiveStoryMap(
            storyCounts: {
              for (final country in data.countries) country.code: country.count,
            },
            totalStories: data.totalStories,
            onCountryTap: (code) {
              final country = data.countries.firstWhere(
                (item) => item.code == code,
              );
              _showFilteredStories(
                context,
                title: 'Stories from ${country.name}',
                leading: const Icon(Icons.public, color: AppTheme.primary),
                queryForPage: (page) =>
                    CatalogueQuery(page: page, country: country.code),
              );
            },
          ),
        ),
  );
}

enum _StoryListMetric { views, rating }

class _StoryList extends StatelessWidget {
  const _StoryList({required this.title, required this.stories, this.metric});
  final String title;
  final List<StorySummary> stories;
  final _StoryListMetric? metric;

  String _compactCount(int value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K';
    }
    return '$value';
  }

  Widget? _metric(BuildContext context, StorySummary story) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return switch (metric) {
      _StoryListMetric.views => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${_compactCount(story.views ?? 0)} views',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
      _StoryListMetric.rating => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
          const SizedBox(width: 3),
          Text(
            (story.rating ?? 0).toStringAsFixed(1),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...stories.map(
            (story) => ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push('/story/${story.slug}'),
              leading: SizedBox(
                width: 42,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: story.coverImage == null
                      ? const ColoredBox(
                          color: AppTheme.muted,
                          child: Icon(Icons.auto_stories, size: 18),
                        )
                      : CachedAppImage(
                          imageUrl: story.coverImage!,
                          fit: BoxFit.cover,
                          decodeWidth: 160,
                          diskCacheWidth: 320,
                          error: (_) => const Icon(Icons.auto_stories),
                        ),
                ),
              ),
              title: Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _metric(context, story),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}
