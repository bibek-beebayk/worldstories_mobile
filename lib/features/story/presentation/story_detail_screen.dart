import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/format_icons.dart';
import '../../../core/modal_sheet_page.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/cached_app_image.dart';
import '../../../shared/widgets/hero_glow.dart';
import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../engagement/presentation/favorite_button.dart';
import '../../engagement/presentation/reactions_row.dart';
import '../data/story_detail_repository.dart';
import '../../../core/api_error_view.dart';

final storyDetailRepositoryProvider = Provider<StoryDetailRepository>(
  (ref) => StoryDetailRepository(ref.watch(apiClientProvider)),
);
final storyDetailProvider = FutureProvider.family<StoryDetail, String>(
  (ref, slug) => ref.watch(storyDetailRepositoryProvider).fetch(slug),
);

class StoryDetailScreen extends ConsumerStatefulWidget {
  const StoryDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends ConsumerState<StoryDetailScreen> {
  final _chapterTabsKey = GlobalKey<_StoryChapterTabsState>();

  String get slug => widget.slug;

  @override
  Widget build(BuildContext context) {
    ref.listen(storyDetailProvider(slug), (previous, next) {
      next.whenData(
        (story) => ref
            .read(analyticsServiceProvider)
            .track(AnalyticsEventType.visit, storySlug: story.slug),
      );
    });
    return Scaffold(
      primary: false,
      backgroundColor: Colors.transparent,
      body: ref
          .watch(storyDetailProvider(slug))
          .when(
            loading: () => const _WithSheetHandle(
              child: Column(children: [_CoverHero(loading: true)]),
            ),
            error: (error, _) => _WithSheetHandle(
              child: Column(
                children: [
                  const _CoverHero(),
                  Expanded(child: ApiErrorView(error: error)),
                ],
              ),
            ),
            data: (story) => _WithSheetHandle(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(storyDetailProvider(slug).future),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    _CoverHero(story: story),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                onPressed: () => context.push(
                                  '/story/${story.slug}/reviews',
                                ),
                                icon: const Icon(Icons.rate_review_outlined),
                                label: Text('${story.reviewsCount}'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ReactionsRow(storySlug: story.slug),
                          _StoryOptionPills(
                            options: _availableChapterTabs(story),
                            onSelected: (type) {
                              final route = _directRoute(story, type);
                              if (route != null) {
                                context.push(route);
                              } else {
                                _chapterTabsKey.currentState?.open(type);
                              }
                            },
                          ),
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
                          _StoryChapterTabs(key: _chapterTabsKey, story: story),
                          if (story.tags.isNotEmpty)
                            _LabelSection(title: 'Tags', values: story.tags),
                          if (story.themes.isNotEmpty)
                            _LabelSection(
                              title: 'Themes',
                              values: story.themes,
                            ),
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

/// Overlays a drag handle on the sheet's top edge, over the cover hero. The
/// strip sits outside the scroll view, so dragging it dismisses the sheet.
class _WithSheetHandle extends StatelessWidget {
  const _WithSheetHandle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: child),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 28,
        child: Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ],
  );
}

/// The cover on the dark hero backdrop. Without a [story] it keeps the same
/// backdrop and size, with an empty cover slot (and a spinner while
/// [loading]), so the sheet's top looks the same in every state. Dragging
/// down on it closes the sheet.
class _CoverHero extends StatelessWidget {
  const _CoverHero({this.story, this.loading = false});

  final StoryDetail? story;
  final bool loading;

  @override
  Widget build(BuildContext context) => SheetDismissDragArea(
    child: Container(
      width: double.infinity,
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
        alignment: Alignment.center,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _coverMaxWidth,
                maxHeight: 360,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                // Eases the jump from the 3:4 loading slot to the cover's
                // own aspect ratio once the image arrives.
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: story == null
                        ? _CoverSlot(
                            child: ColoredBox(
                              color: const Color(0x14FFFFFF),
                              child: loading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white70,
                                      ),
                                    )
                                  : null,
                            ),
                          )
                        : _Cover(story: story!),
                  ),
                ),
              ),
            ),
          ),
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
  const _StoryChapterTabs({super.key, required this.story});

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
    availableTabs = _availableChapterTabs(widget.story);
    controller = TabController(length: availableTabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _StoryChapterTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedTabs = _availableChapterTabs(widget.story);
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

  /// Switches to [type]'s tab and scrolls the chapters section into view.
  void open(_ChapterTabType type) {
    final index = availableTabs.indexOf(type);
    if (index < 0) return;
    controller.animateTo(index);
    setState(() => selectedIndex = index);
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
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

  Widget _contentFor(_ChapterTabType type, BuildContext context) =>
      _ChapterList(
        entries: [
          for (final entry in _chapterEntries(widget.story, type))
            _ChapterTile(
              icon: entry.icon,
              title: entry.title,
              onTap: () => context.push(entry.route),
            ),
        ],
        emptyMessage: switch (type) {
          _ChapterTabType.read => 'No reading chapters available.',
          _ChapterTabType.audio => 'No audio chapters available.',
          _ChapterTabType.readAlong => 'No read-along chapters available.',
          _ChapterTabType.watch => 'No video chapters available.',
        },
      );
}

/// One row in a chapters tab: what it's called and where it opens.
final class _ChapterEntry {
  const _ChapterEntry(this.icon, this.title, this.route);

  final IconData icon;
  final String title;
  final String route;
}

List<_ChapterEntry> _chapterEntries(StoryDetail story, _ChapterTabType type) =>
    switch (type) {
      _ChapterTabType.read => [
        for (final chapter in story.chapters)
          _ChapterEntry(
            FormatIcons.read,
            '${chapter.order}. ${chapter.title}',
            '/read/${story.slug}/${chapter.slug}',
          ),
        if (story.summary.isNotEmpty)
          _ChapterEntry(
            FormatIcons.quickRead,
            'Quick Read',
            '/quick-read/${story.slug}',
          ),
        if (story.pdfFile != null)
          _ChapterEntry(
            Icons.picture_as_pdf,
            'Read as PDF',
            '/read-pdf/${story.slug}',
          ),
        if (story.epubFile != null)
          _ChapterEntry(
            Icons.menu_book_outlined,
            'Read as EPUB',
            '/read-epub/${story.slug}',
          ),
      ],
      _ChapterTabType.audio => [
        for (final audio in story.audios)
          _ChapterEntry(
            FormatIcons.listen,
            audio.title,
            '/listen/${story.slug}/${audio.slug}',
          ),
      ],
      _ChapterTabType.readAlong => [
        for (final audio in story.audios)
          if (audio.readAlongAvailable)
            _ChapterEntry(
              FormatIcons.readAlong,
              audio.title,
              '/read-along/${story.slug}/${audio.slug}',
            ),
      ],
      _ChapterTabType.watch => [
        for (final video in story.videos)
          if (video.id != null)
            _ChapterEntry(
              FormatIcons.watch,
              video.title,
              '/watch/${video.id}',
            ),
      ],
    };

/// Where an option pill should go straight to, skipping the chapter list,
/// when its tab has exactly one thing to open.
String? _directRoute(StoryDetail story, _ChapterTabType type) {
  final entries = _chapterEntries(story, type);
  return entries.length == 1 ? entries.single.route : null;
}

enum _ChapterTabType {
  read('Read', 'Read', FormatIcons.read, FormatColors.read),
  audio('Audio', 'Listen', FormatIcons.listen, FormatColors.listen),
  readAlong(
    'Read Along',
    'Read Along',
    FormatIcons.readAlong,
    FormatColors.readAlong,
  ),
  watch('Watch', 'Watch', FormatIcons.watch, FormatColors.watch);

  const _ChapterTabType(this.label, this.actionLabel, this.icon, this.color);

  /// Tab title in the chapters section.
  final String label;

  /// Verb shown on the story option pill.
  final String actionLabel;
  final IconData icon;

  /// Pill color; each format gets its own so they're easy to tell apart.
  final Color color;
}

/// The formats this story offers, in chapter-tab order.
List<_ChapterTabType> _availableChapterTabs(StoryDetail story) => [
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

/// One pill per available format; tapping one opens its chapters tab.
class _StoryOptionPills extends StatelessWidget {
  const _StoryOptionPills({required this.options, required this.onSelected});

  final List<_ChapterTabType> options;
  final ValueChanged<_ChapterTabType> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final option in options)
            ActionChip(
              avatar: Icon(option.icon, size: 20, color: Colors.white),
              label: Text(option.actionLabel),
              labelStyle: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: option.color,
              elevation: 3,
              pressElevation: 1,
              shadowColor: option.color.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onPressed: () => onSelected(option),
            ),
        ],
      ),
    );
  }
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
    if (story.coverImage == null || story.coverImage!.isEmpty) {
      return _CoverSlot(child: fallback);
    }
    // No fixed size: the image lays out at its own aspect ratio, scaled down
    // to fit the hero's max width and height.
    return CachedAppImage(
      imageUrl: story.coverImage!,
      fit: BoxFit.contain,
      decodeWidth: 900,
      diskCacheWidth: 900,
      placeholder: (_) => const _CoverSlot(child: BookPageOpeningLoader()),
      error: (_) => _CoverSlot(child: fallback),
    );
  }
}

const _coverMaxWidth = 230.0;

/// A 3:4 cover-sized box for content with no aspect ratio of its own: the
/// loading placeholder and the generated fallback cover.
class _CoverSlot extends StatelessWidget {
  const _CoverSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _coverMaxWidth,
    child: AspectRatio(aspectRatio: 3 / 4, child: child),
  );
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
