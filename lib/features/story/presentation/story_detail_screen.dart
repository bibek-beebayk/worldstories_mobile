import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/cached_app_image.dart';
import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../engagement/data/story_recommendations_repository.dart';
import '../../engagement/presentation/favorite_button.dart';
import '../../engagement/presentation/reactions_row.dart';
import '../../home/data/home_repository.dart';
import '../data/story_detail_repository.dart';
import '../../../core/api_error_view.dart';

final becauseFinishedProvider =
    FutureProvider.family<List<StorySummary>, String>(
      (ref, storySlug) => ref
          .read(storyRecommendationsRepositoryProvider)
          .becauseFinished(storySlug),
    );

final storyDetailRepositoryProvider = Provider<StoryDetailRepository>(
  (ref) => StoryDetailRepository(ref.watch(apiClientProvider)),
);
final storyDetailProvider = FutureProvider.family<StoryDetail, String>(
  (ref, slug) => ref.watch(storyDetailRepositoryProvider).fetch(slug),
);

class StoryDetailScreen extends ConsumerWidget {
  const StoryDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(storyDetailProvider(slug), (previous, next) {
      next.whenData(
        (story) => ref
            .read(analyticsServiceProvider)
            .track(AnalyticsEventType.visit, storySlug: story.slug),
      );
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
      body: ref
          .watch(storyDetailProvider(slug))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ApiErrorView(error: error),
            data: (story) => RefreshIndicator(
              onRefresh: () => ref.refresh(storyDetailProvider(slug).future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  Center(
                    child: SizedBox(
                      width: 230,
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _Cover(story: story),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (story.storyType.isNotEmpty)
                        Chip(label: Text(story.storyType)),
                      if (story.language.isNotEmpty)
                        Chip(label: Text(story.language.toUpperCase())),
                    ],
                  ),
                  Text(
                    story.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (story.author != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'by ${story.author}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 18,
                    children: [
                      Text('★ ${story.rating.toStringAsFixed(1)}'),
                      Text('${story.views} views'),
                      if (story.publishedLabel != null)
                        Text(story.publishedLabel!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FavoriteButton(
                        storySlug: story.slug,
                        initialIsFavorite: story.isFavorite,
                        initialFavoritesCount: story.favoritesCount,
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () =>
                            context.push('/story/${story.slug}/reviews'),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text('${story.reviewsCount}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ReactionsRow(storySlug: story.slug),
                  if (story.about.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.about,
                      textAlign: TextAlign.justify,
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                  if (story.authorDetails != null)
                    _AuthorSection(author: story.authorDetails!),
                  _StoryChapterTabs(story: story),
                  if (story.tags.isNotEmpty)
                    _LabelSection(title: 'Tags', values: story.tags),
                  if (story.themes.isNotEmpty)
                    _LabelSection(title: 'Themes', values: story.themes),
                  if (story.similarStories.isNotEmpty)
                    _RecommendationGrid(
                      title: 'Similar stories',
                      stories: story.similarStories,
                    ),
                  Consumer(
                    builder: (context, ref, _) => ref
                        .watch(becauseFinishedProvider(story.slug))
                        .when(
                          loading: () => const SizedBox.shrink(),
                          // 401 for anonymous readers (this endpoint requires
                          // auth) is expected and should stay invisible rather
                          // than showing an error card.
                          error: (_, _) => const SizedBox.shrink(),
                          data: (recommendations) => recommendations.isEmpty
                              ? const SizedBox.shrink()
                              : _RecommendationGrid(
                                  title: 'Because you finished this',
                                  stories: recommendations,
                                ),
                        ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _RecommendationGrid extends StatelessWidget {
  const _RecommendationGrid({required this.title, required this.stories});

  final String title;
  final List<StorySummary> stories;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
            childAspectRatio: 0.54,
          ),
          itemBuilder: (context, index) =>
              _RecommendationCard(story: stories[index]),
        ),
      ],
    ),
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.story});

  final StorySummary story;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: story.slug.isEmpty
        ? null
        : () => context.push('/story/${story.slug}'),
    borderRadius: BorderRadius.circular(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: _RecommendationCover(story: story),
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

class _RecommendationCover extends StatelessWidget {
  const _RecommendationCover({required this.story});

  final StorySummary story;

  @override
  Widget build(BuildContext context) {
    final fallback = _RecommendationFallbackCover(story: story);
    final image = story.coverImage;
    if (image == null || image.trim().isEmpty) return fallback;
    return CachedAppImage(
      imageUrl: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      error: (_) => fallback,
    );
  }
}

class _RecommendationFallbackCover extends StatelessWidget {
  const _RecommendationFallbackCover({required this.story});

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
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WORLDSTORIES',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 6,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Text(
            story.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (story.author != null && story.author!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              story.author!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 8),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AuthorSection extends StatelessWidget {
  const _AuthorSection({required this.author});

  final StoryAuthor author;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text('About the Author', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            _AuthorAvatar(author: author),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${author.storiesCount} ${author.storiesCount == 1 ? 'story' : 'stories'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          author.bio.isEmpty ? 'No author bio available.' : author.bio,
          textAlign: TextAlign.justify,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    ),
  );
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.author});

  final StoryAuthor author;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppTheme.primary.withValues(alpha: 0.14),
      child: Center(
        child: Text(
          author.name.trim().isEmpty
              ? '?'
              : author.name.trim()[0].toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final image = author.image;
    return SizedBox.square(
      dimension: 48,
      child: ClipOval(
        child: image == null || image.trim().isEmpty
            ? fallback
            : CachedAppImage(
                imageUrl: image,
                fit: BoxFit.cover,
                decodeWidth: 144,
                diskCacheWidth: 288,
                placeholder: (_) => fallback,
                error: (_) => fallback,
              ),
      ),
    );
  }
}

class _StoryChapterTabs extends StatefulWidget {
  const _StoryChapterTabs({required this.story});

  final StoryDetail story;

  @override
  State<_StoryChapterTabs> createState() => _StoryChapterTabsState();
}

class _StoryChapterTabsState extends State<_StoryChapterTabs>
    with SingleTickerProviderStateMixin {
  late TabController controller;
  late List<_ChapterTabType> availableTabs;
  var selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    availableTabs = _tabsFor(widget.story);
    controller = TabController(length: availableTabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _StoryChapterTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedTabs = _tabsFor(widget.story);
    final tabsChanged =
        updatedTabs.length != availableTabs.length ||
        updatedTabs.indexed.any((entry) => entry.$2 != availableTabs[entry.$1]);
    if (tabsChanged) {
      controller.dispose();
      availableTabs = updatedTabs;
      selectedIndex = 0;
      controller = TabController(length: availableTabs.length, vsync: this);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (availableTabs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chapters', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            onTap: (index) => setState(() => selectedIndex = index),
            tabs: availableTabs.map((type) => Tab(text: type.label)).toList(),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(selectedIndex),
              child: _contentFor(availableTabs[selectedIndex], context),
            ),
          ),
        ],
      ),
    );
  }

  List<_ChapterTabType> _tabsFor(StoryDetail story) => [
    if (story.chapters.isNotEmpty ||
        story.summary.isNotEmpty ||
        story.pdfFile != null ||
        story.epubFile != null)
      _ChapterTabType.read,
    if (story.audios.isNotEmpty) _ChapterTabType.audio,
    if (story.audios.any((audio) => audio.readAlongAvailable))
      _ChapterTabType.readAlong,
    if (story.videos.isNotEmpty) _ChapterTabType.watch,
  ];

  Widget _contentFor(_ChapterTabType type, BuildContext context) =>
      switch (type) {
        _ChapterTabType.read => _readChapters(context),
        _ChapterTabType.audio => _audioChapters(context),
        _ChapterTabType.readAlong => _readAlongChapters(context),
        _ChapterTabType.watch => _watchChapters(context),
      };

  Widget _readChapters(BuildContext context) {
    final story = widget.story;
    final entries = <Widget>[
      ...story.chapters.map(
        (chapter) => _ChapterTile(
          icon: Icons.menu_book,
          title: '${chapter.order}. ${chapter.title}',
          onTap: () => context.push('/read/${story.slug}/${chapter.slug}'),
        ),
      ),
      if (story.summary.isNotEmpty)
        _ChapterTile(
          icon: Icons.bolt,
          title: 'Quick Read',
          onTap: () => context.push('/quick-read/${story.slug}'),
        ),
      if (story.pdfFile != null)
        _ChapterTile(
          icon: Icons.picture_as_pdf,
          title: 'Read as PDF',
          onTap: () => context.push('/read-pdf/${story.slug}'),
        ),
      if (story.epubFile != null)
        _ChapterTile(
          icon: Icons.menu_book_outlined,
          title: 'Read as EPUB',
          onTap: () => context.push('/read-epub/${story.slug}'),
        ),
    ];
    return _ChapterList(
      entries: entries,
      emptyMessage: 'No reading chapters available.',
    );
  }

  Widget _audioChapters(BuildContext context) => _ChapterList(
    entries: widget.story.audios
        .map(
          (audio) => _ChapterTile(
            icon: Icons.headphones,
            title: audio.title,
            onTap: () =>
                context.push('/listen/${widget.story.slug}/${audio.slug}'),
          ),
        )
        .toList(),
    emptyMessage: 'No audio chapters available.',
  );

  Widget _readAlongChapters(BuildContext context) => _ChapterList(
    entries: widget.story.audios
        .where((audio) => audio.readAlongAvailable)
        .map(
          (audio) => _ChapterTile(
            icon: Icons.subtitles,
            title: audio.title,
            onTap: () =>
                context.push('/read-along/${widget.story.slug}/${audio.slug}'),
          ),
        )
        .toList(),
    emptyMessage: 'No read-along chapters available.',
  );

  Widget _watchChapters(BuildContext context) => _ChapterList(
    entries: widget.story.videos
        .map(
          (video) => _ChapterTile(
            icon: Icons.play_circle,
            title: video.title,
            onTap: () =>
                context.push('/watch/${widget.story.slug}/${video.slug}'),
          ),
        )
        .toList(),
    emptyMessage: 'No video chapters available.',
  );
}

enum _ChapterTabType {
  read('Read'),
  audio('Audio'),
  readAlong('Read Along'),
  watch('Watch');

  const _ChapterTabType(this.label);

  final String label;
}

class _ChapterList extends StatelessWidget {
  const _ChapterList({required this.entries, required this.emptyMessage});

  final List<Widget> entries;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (entries.isNotEmpty) {
      return Column(children: entries);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      color: AppTheme.muted,
      child: Text(
        emptyMessage,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.story});
  final StoryDetail story;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.heroDark,
            AppTheme.heroGradientEnd,
            Color(0xFF4A2030),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WORLDSTORIES',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Text(
            story.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (story.author != null) ...[
            const SizedBox(height: 10),
            Text(story.author!, style: const TextStyle(color: Colors.white70)),
          ],
        ],
      ),
    );
    if (story.coverImage == null || story.coverImage!.isEmpty) return fallback;
    return CachedAppImage(
      imageUrl: story.coverImage!,
      fit: BoxFit.cover,
      decodeWidth: 900,
      diskCacheWidth: 900,
      error: (_) => fallback,
    );
  }
}

class _LabelSection extends StatelessWidget {
  const _LabelSection({required this.title, required this.values});
  final String title;
  final List<String> values;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ExpansionTile(
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: values.map((value) => Chip(label: Text(value))).toList(),
          ),
        ),
      ],
    ),
  );
}
