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
import '../data/home_repository.dart';

final homeSnapshotProvider = FutureProvider<HomeSnapshot>(
  (ref) => ref.watch(homeRepositoryProvider).fetchHome(),
);

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
      data: _homeSections,
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
          onRefresh: () => ref.refresh(homeSnapshotProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _HomeHero(
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

List<Widget> _homeSections(HomeSnapshot snapshot) {
  final featured = snapshot.dailyStoryConfigured && snapshot.dailyStory != null
      ? [snapshot.dailyStory!]
      : snapshot.featured;
  Widget padded(Widget child, {double top = 0, double bottom = 0}) =>
      Padding(padding: EdgeInsets.fromLTRB(12, top, 12, bottom), child: child);

  return [
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
        icon: Icons.bolt,
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
    required this.stats,
    required this.onStart,
    required this.onSurprise,
  });
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
          child: _HeroGlow(size: 280, opacity: 0.14),
        ),
        const Positioned(
          left: -115,
          bottom: -155,
          child: _HeroGlow(size: 310, opacity: 0.08),
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
                    icon: Icons.menu_book,
                    text: 'Full novels, quick reads & poetry',
                  ),
                  _HeroFact(
                    icon: Icons.headphones,
                    text: 'Audiobooks & read-along narration',
                  ),
                ],
              ),
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

class _HeroGlow extends StatelessWidget {
  const _HeroGlow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppTheme.primary.withValues(alpha: opacity),
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
