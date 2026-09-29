import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_exception.dart';
import '../../../core/app_theme.dart';
import '../../../core/providers.dart';
import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/data/story_recommendations_repository.dart';
import '../../story/data/story_detail_repository.dart';
import '../../../shared/widgets/cached_app_image.dart';
import '../../../shared/widgets/hero_glow.dart';
import '../data/home_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../library/data/library_repository.dart';
import '../../../core/format_icons.dart';

final homeSnapshotProvider = FutureProvider<HomeSnapshot>(
  (ref) => ref.watch(homeRepositoryProvider).fetchHome(),
);

/// Recommendations for the signed-in reader. A failure just hides the
/// section rather than breaking the home screen.
final homeForYouProvider = FutureProvider<List<StorySummary>>((ref) async {
  // Re-fetch when a different reader signs in.
  ref.watch(authControllerProvider.select((auth) => auth.value?.username));
  try {
    return await ref.watch(libraryRepositoryProvider).fetchRecommendations();
  } on Object {
    return const [];
  }
});

/// The reader's in-progress stories across every format, most recent first.
final homeContinueProvider = FutureProvider<List<_ContinueEntry>>((ref) async {
  // Re-fetch when a different reader signs in.
  ref.watch(authControllerProvider.select((auth) => auth.value?.username));
  final repository = ref.watch(libraryRepositoryProvider);
  Future<List<_ContinueEntry>> load(_ContinueFormat format) async {
    try {
      final page = await repository.fetch(format.endpoint);
      return [
        for (final item in page.items)
          if (item.story.slug.isNotEmpty) _ContinueEntry(format, item),
      ];
    } on Object {
      return const [];
    }
  }

  final results = await Future.wait(_ContinueFormat.values.map(load));
  final entries = results.expand((list) => list).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return entries.take(10).toList();
});

Future<void> showSurpriseStoryDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _SurpriseStoryDialog(),
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeSnapshotProvider);
    final user = ref.watch(authControllerProvider).value;
    final signedIn = user != null;
    final continueEntries = signedIn
        ? ref.watch(homeContinueProvider).value ?? const <_ContinueEntry>[]
        : const <_ContinueEntry>[];
    final forYou = signedIn
        ? ref.watch(homeForYouProvider).value ?? const <StorySummary>[]
        : const <StorySummary>[];
    final content = home.when<List<Widget>>(
      loading: () => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, stack) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 32, 12, 40),
          child: _ErrorCard(
            message: error is ApiException ? error.message : error.toString(),
            throttled: error is ThrottledException,
            onRetry: () => ref.invalidate(homeSnapshotProvider),
          ),
        ),
      ],
      data: (snapshot) => _homeSections(
        snapshot,
        continueEntries: continueEntries,
        forYou: forYou,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'World'),
              TextSpan(
                text: 'Stories',
                style: TextStyle(color: AppTheme.primary),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
          ),
          IconButton(
            onPressed: () => context.push('/discover'),
            icon: const Icon(Icons.explore),
            tooltip: 'Discover',
          ),
          IconButton(
            onPressed: () => context.push('/blog'),
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Blog',
          ),
          IconButton(
            onPressed: () => context.go(user == null ? '/sign-in' : '/profile'),
            icon: _ProfileAvatar(
              signedIn: user != null,
              imageUrl: user?.avatarUrl,
              label: user?.displayName ?? user?.username ?? user?.email,
            ),
            tooltip: 'Account',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.refresh(homeSnapshotProvider.future),
            if (signedIn) ...[
              ref.refresh(homeContinueProvider.future),
              ref.refresh(homeForYouProvider.future),
            ],
          ]),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _HomeHero(
                firstName: _firstName(user),
                stats: home.value?.stats,
                onStart: () => context.go('/library'),
                onSurprise: () async {
                  ref
                      .read(analyticsServiceProvider)
                      .track(AnalyticsEventType.surpriseMeClicked);
                  await showSurpriseStoryDialog(context);
                },
              ),
              ...content,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.signedIn,
    required this.imageUrl,
    required this.label,
  });

  final bool signedIn;
  final String? imageUrl;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!signedIn) return const Icon(Icons.account_circle);

    final name = label?.trim() ?? '';
    final fallback = ColoredBox(
      color: AppTheme.primary.withValues(alpha: 0.16),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final url = imageUrl?.trim();
    return SizedBox.square(
      dimension: 30,
      child: ClipOval(
        child: url == null || url.isEmpty
            ? fallback
            : CachedAppImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: 30,
                height: 30,
                decodeWidth: 96,
                diskCacheWidth: 192,
                placeholder: (_) => fallback,
                error: (_) => fallback,
              ),
      ),
    );
  }
}

class _SurpriseStoryDialog extends ConsumerStatefulWidget {
  const _SurpriseStoryDialog();

  @override
  ConsumerState<_SurpriseStoryDialog> createState() =>
      _SurpriseStoryDialogState();
}

class _SurpriseStoryDialogState extends ConsumerState<_SurpriseStoryDialog> {
  late Future<_SurpriseResult> suggestion;

  @override
  void initState() {
    super.initState();
    suggestion = _loadSuggestion();
  }

  Future<_SurpriseResult> _loadSuggestion({String? exclude}) async {
    final summary = await ref
        .read(storyRecommendationsRepositoryProvider)
        .surprise(exclude: exclude);
    if (summary == null || summary.slug.isEmpty) {
      throw const FormatException(
        'No story suggestion is available right now.',
      );
    }

    StoryDetail? details;
    try {
      details = await StoryDetailRepository(
        ref.read(apiClientProvider),
      ).fetch(summary.slug);
    } catch (_) {
      // The suggestion itself is still useful if expanded details fail to load.
    }
    return _SurpriseResult(summary: summary, details: details);
  }

  void _retry() => setState(() {
    suggestion = _loadSuggestion();
  });

  void _suggestAnother(String currentSlug) => setState(() {
    suggestion = _loadSuggestion(exclude: currentSlug);
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: FutureBuilder<_SurpriseResult>(
        future: suggestion,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 18),
                  Text('Finding a story for you…'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ApiException
                ? error.message
                : 'Could not find a story right now.';
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 36),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return _SurpriseStoryContent(
            result: snapshot.requireData,
            onSuggestAnother: () =>
                _suggestAnother(snapshot.requireData.summary.slug),
          );
        },
      ),
    ),
  );
}

class _SurpriseResult {
  const _SurpriseResult({required this.summary, required this.details});

  final StorySummary summary;
  final StoryDetail? details;
}

class _SurpriseStoryContent extends StatelessWidget {
  const _SurpriseStoryContent({
    required this.result,
    required this.onSuggestAnother,
  });

  final _SurpriseResult result;
  final VoidCallback onSuggestAnother;

  @override
  Widget build(BuildContext context) {
    final story = result.summary;
    final details = result.details;
    final author = details?.author ?? story.author;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Your surprise story',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            color: AppTheme.primary.withValues(alpha: 0.08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _StoryCover(story: story),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (author != null && author.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('by $author'),
                      ],
                      if (details != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (details.storyType.isNotEmpty)
                              Chip(
                                label: Text(details.storyType),
                                backgroundColor: AppTheme.primary.withValues(
                                  alpha: 0.14,
                                ),
                                labelStyle: const TextStyle(fontSize: 11),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -3,
                                ),
                              ),
                            if (details.language.isNotEmpty)
                              Chip(
                                label: Text(details.language.toUpperCase()),
                                backgroundColor: const Color(0xFFDBEAFE),
                                labelStyle: const TextStyle(fontSize: 11),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -3,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '★ ${details.rating.toStringAsFixed(1)}  •  ${details.views} views',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (details != null &&
              (details.about.isNotEmpty || details.summary.isNotEmpty)) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 180,
              child: SingleChildScrollView(
                child: Text(
                  details.about.isNotEmpty ? details.about : details.summary,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSuggestAnother,
                  child: const Text('Another'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('/story/${story.slug}');
                  },
                  child: const Text('Open Story'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<Widget> _homeSections(
  HomeSnapshot snapshot, {
  required List<_ContinueEntry> continueEntries,
  required List<StorySummary> forYou,
}) {
  final featured = snapshot.dailyStoryConfigured && snapshot.dailyStory != null
      ? [snapshot.dailyStory!]
      : snapshot.featured;
  Widget padded(Widget child, {double top = 0, double bottom = 0}) =>
      Padding(padding: EdgeInsets.fromLTRB(12, top, 12, bottom), child: child);

  return [
    if (continueEntries.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 32),
        child: _ContinueRail(entries: continueEntries),
      ),
    padded(
      _StoryGrid(
        title: snapshot.dailyStoryConfigured
            ? 'Daily Story'
            : 'Featured Stories',
        icon: Icons.auto_awesome,
        stories: featured,
      ),
      top: 32,
    ),
    padded(
      _StoryGrid(
        title: 'Picked for You',
        icon: Icons.favorite_border,
        stories: forYou.take(6).toList(),
      ),
    ),
    padded(_OriginalsSection(stories: snapshot.originals)),
    const SizedBox(height: 32),
    padded(
      _StoryGrid(
        title: 'New Entries',
        icon: Icons.rss_feed,
        stories: snapshot.newTrending.take(4).toList(),
      ),
    ),
    padded(
      const _PromoBanner(
        colors: [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFF4F46E5)],
        icon: Icons.route,
        title: 'Story Journeys',
        description: 'Curated paths through countries, genres, and themes.',
        action: 'Explore journeys',
        route: '/journeys',
      ),
    ),
    const SizedBox(height: 32),
    padded(
      _StoryGrid(
        title: 'Quick Reads',
        icon: FormatIcons.quickRead,
        stories: snapshot.quickReads.take(6).toList(),
      ),
    ),
    padded(
      const _PromoBanner(
        colors: [Color(0xFF0891B2), Color(0xFF2563EB), Color(0xFF0D9488)],
        icon: Icons.public,
        title: 'Explore by Country',
        description: 'Follow a story back to where it comes from.',
        action: 'Open the Story Map',
        route: '/story-map',
      ),
    ),
    const SizedBox(height: 32),
    padded(
      _StoryGrid(
        title: 'Continue Discovering',
        icon: Icons.explore,
        stories: snapshot.moreToExplore.take(6).toList(),
      ),
      bottom: 40,
    ),
  ];
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.firstName,
    required this.stats,
    required this.onStart,
    required this.onSurprise,
  });

  /// When set, the hero greets the reader instead of pitching the app.
  final String? firstName;
  final CommunityStats? stats;
  final VoidCallback onStart;
  final VoidCallback onSurprise;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.hardEdge,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.heroDark,
          AppTheme.heroGradientEnd,
          Color(0xFF35202D),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          right: -90,
          top: -105,
          child: HeroGlow(size: 280, opacity: 0.14),
        ),
        const Positioned(
          left: -115,
          bottom: -155,
          child: HeroGlow(size: 310, opacity: 0.08),
        ),
        const Positioned(
          right: 10,
          top: 78,
          child: Opacity(
            opacity: 0.08,
            child: Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 130,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 36, 16, 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (firstName != null)
                _HeroGreeting(firstName: firstName!)
              else ...[
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 40,
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'World',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'Stories',
                        style: TextStyle(color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The home for stories from around the world. Read novels, poetry, and short fiction for free, and discover audiobooks and read-along narrations.',
                  style: TextStyle(color: Color(0xBFFFFFFF), height: 1.45),
                ),
                const SizedBox(height: 18),
                const Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _HeroFact(
                      icon: FormatIcons.read,
                      text: 'Full novels, quick reads & poetry',
                    ),
                    _HeroFact(
                      icon: FormatIcons.listen,
                      text: 'Audiobooks & read-along narration',
                    ),
                  ],
                ),
              ],
              if (stats != null) ...[
                const SizedBox(height: 18),
                Text(
                  '${stats!.stories} stories   ${stats!.creators} creators   ${stats!.readers} readers',
                  style: const TextStyle(
                    color: Color(0xBFFFFFFF),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Start Reading'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onSurprise,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Surprise Me'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}

class _StoryGrid extends StatelessWidget {
  const _StoryGrid({
    required this.title,
    required this.icon,
    required this.stories,
  });
  final String title;
  final IconData icon;
  final List<StorySummary> stories;
  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 18,
              childAspectRatio: .58,
            ),
            itemBuilder: (context, index) =>
                _GridStoryCard(story: stories[index]),
          ),
        ],
      ),
    );
  }
}

class _GridStoryCard extends StatelessWidget {
  const _GridStoryCard({required this.story});
  final StorySummary story;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: story.slug.isEmpty
        ? null
        : () => context.push('/story/${story.slug}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _StoryCover(story: story),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: Text(
            story.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    ),
  );
}

class _StoryCover extends StatelessWidget {
  const _StoryCover({required this.story});
  final StorySummary story;

  @override
  Widget build(BuildContext context) {
    final fallback = _FallbackCover(story: story);
    final url = story.coverImage;
    if (url == null || url.trim().isEmpty) return fallback;
    return CachedAppImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      error: (_) => fallback,
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.story});
  final StorySummary story;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.heroDark,
          AppTheme.heroGradientEnd,
          Color(0xFF4A2030),
        ],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'WORLDSTORIES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          const Spacer(),
          const Icon(Icons.auto_stories, color: Colors.white54, size: 28),
          const SizedBox(height: 10),
          Text(
            story.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (story.author case final author?) ...[
            const SizedBox(height: 8),
            Text(
              author,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.colors,
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.route,
  });
  final List<Color> colors;
  final IconData icon;
  final String title;
  final String description;
  final String action;
  final String route;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: Colors.white24,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => context.push(route),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}

class _OriginalsSection extends StatelessWidget {
  const _OriginalsSection({required this.stories});
  final List<StorySummary> stories;
  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Colors.white, Color(0xFFEFF6FF)],
        ),
        border: Border.all(color: const Color(0xFFC7D2FE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '✦  WORLDSTORIES ORIGINALS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Exclusive stories published in-house for the WorldStories community.',
            style: TextStyle(color: AppTheme.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stories.take(6).length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 18,
              childAspectRatio: .58,
            ),
            itemBuilder: (context, index) =>
                _GridStoryCard(story: stories[index]),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.throttled,
    required this.onRetry,
  });
  final String message;
  final bool throttled;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            throttled ? 'Too many requests' : 'Could not reach WorldStories',
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

String? _firstName(UserProfile? user) {
  if (user == null) return null;
  final name = (user.displayName?.trim().isNotEmpty ?? false)
      ? user.displayName!.trim().split(RegExp(r'\s+')).first
      : user.username.trim();
  return name.isEmpty ? null : name;
}

class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({required this.firstName});

  final String firstName;

  String get _timeOfDay {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$_timeOfDay,',
        style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 18),
      ),
      const SizedBox(height: 4),
      Text(
        firstName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 40,
          fontFamily: AppTheme.displayFont,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Pick up where you left off, or find a new story from somewhere in the world.',
        style: TextStyle(color: Color(0xBFFFFFFF), height: 1.45),
      ),
    ],
  );
}

enum _ContinueFormat {
  reading('continue-reading', 'Reading', FormatIcons.read, FormatColors.read),
  listening(
    'continue-listening',
    'Listening',
    FormatIcons.listen,
    FormatColors.listen,
  ),
  watching(
    'continue-watching',
    'Watching',
    FormatIcons.watch,
    FormatColors.watch,
  );

  const _ContinueFormat(this.endpoint, this.label, this.icon, this.color);

  final String endpoint;
  final String label;
  final IconData icon;
  final Color color;
}

final class _ContinueEntry {
  const _ContinueEntry(this.format, this.item);

  final _ContinueFormat format;
  final LibraryItem item;

  StorySummary get story => item.story;

  DateTime get updatedAt =>
      DateTime.tryParse(item.raw['updated_at'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String? get partTitle => switch (format) {
    _ContinueFormat.reading => item.chapterTitle,
    _ContinueFormat.listening => item.audioTitle,
    _ContinueFormat.watching => item.videoTitle,
  };

  /// Resumes the exact chapter/audio/video when the API names one,
  /// otherwise opens the story sheet.
  String get route {
    final slug = story.slug;
    final part = switch (format) {
      _ContinueFormat.reading => item.raw['chapter_slug'],
      _ContinueFormat.listening => item.raw['audio_slug'],
      _ContinueFormat.watching => item.raw['video_slug'],
    };
    if (part is! String || part.isEmpty) return '/story/$slug';
    return switch (format) {
      _ContinueFormat.reading => '/read/$slug/$part',
      _ContinueFormat.listening => '/listen/$slug/$part',
      _ContinueFormat.watching => '/watch/$slug/$part',
    };
  }
}

/// "Continue where you left off": the reader's latest unfinished stories
/// across reading, listening and watching, color coded by format.
class _ContinueRail extends StatelessWidget {
  const _ContinueRail({required this.entries});

  final List<_ContinueEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.history, size: 22, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Continue Where You Left Off',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) => _ContinueCard(entry: entries[index]),
        ),
      ),
    ],
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry});

  final _ContinueEntry entry;

  @override
  Widget build(BuildContext context) {
    final format = entry.format;
    final progress = entry.item.overallProgress?.clamp(0.0, 1.0);
    final remaining = entry.item.remainingMinutes;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 280,
      child: Material(
        color: format.color.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(color: format.color.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(entry.route),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _StoryCover(story: entry.story),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(format.icon, size: 15, color: format.color),
                          const SizedBox(width: 5),
                          Text(
                            format.label,
                            style: textTheme.labelMedium?.copyWith(
                              color: format.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.story.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                      if (entry.partTitle != null)
                        Text(
                          entry.partTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      const Spacer(),
                      if (progress != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            color: format.color,
                            backgroundColor: format.color.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            '${(progress * 100).round()}%',
                            if (remaining != null) '$remaining min left',
                          ].join(' • '),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
