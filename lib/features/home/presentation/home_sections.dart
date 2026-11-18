part of 'home_screen.dart';

/// Keeps the same story from appearing in rail after rail down the page,
/// mirroring the web app's rail de-duplication: the highest-priority rail
/// keeps a story and lower ones drop it.
class _RailDedup {
  final _claimed = <String>{};

  void reserve(Iterable<String?> slugs) {
    for (final slug in slugs) {
      if (slug != null && slug.isNotEmpty) _claimed.add(slug);
    }
  }

  /// Stories this rail may show; `limit` applies after filtering so a rail
  /// that loses stories to higher ones still fills up.
  List<StorySummary> claim(List<StorySummary> stories, {int? limit}) {
    final kept = <StorySummary>[];
    for (final story in stories) {
      if (story.slug.isNotEmpty && _claimed.contains(story.slug)) continue;
      kept.add(story);
      if (story.slug.isNotEmpty) _claimed.add(story.slug);
      if (limit != null && kept.length >= limit) break;
    }
    return kept;
  }
}

/// Maps a web link coming from the backend onto a route this app has.
/// Returns null for anything with no mobile equivalent (the button is hidden).
String? _mobileRoute(String url) {
  if (url.isEmpty || !url.startsWith('/')) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final path = uri.path;
  if (path == '/library') {
    final moods = uri.queryParameters['moods'];
    return moods == null || moods.isEmpty
        ? '/library'
        : Uri(path: '/library', queryParameters: {'moods': moods}).toString();
  }
  if (path == '/quick-reads' || path == '/originals') return '/library';
  if (path.startsWith('/read/')) return '/story/${path.substring(6)}';
  if (path.startsWith('/profile')) return '/my-library';
  const known = [
    '/watch',
    '/blog',
    '/journeys',
    '/story-map',
    '/discover',
    '/trending',
    '/search',
    '/moods',
    '/passport',
    '/stats',
    '/story/',
  ];
  return known.any((prefix) => path == prefix || path.startsWith(prefix))
      ? url
      : null;
}

/// The icon names an admin can pick (HOME_SECTION_ICON_NAMES in the backend).
IconData? _sectionIcon(String name) => const {
  'BookOpen': Icons.menu_book,
  'Zap': Icons.bolt,
  'Youtube': Icons.smart_display,
  'Newspaper': Icons.newspaper,
  'Sparkles': Icons.auto_awesome,
  'Star': Icons.star_outline,
  'Flame': Icons.local_fire_department,
  'Headphones': Icons.headphones,
  'Globe2': Icons.public,
  'Heart': Icons.favorite_border,
  'Clock3': Icons.schedule,
  'Rss': Icons.rss_feed,
  'Captions': Icons.closed_caption_outlined,
  'Trophy': Icons.emoji_events_outlined,
  'Crown': Icons.workspace_premium,
  'Music': Icons.music_note,
  'Mic2': Icons.mic,
  'Feather': Icons.draw_outlined,
  'Leaf': Icons.eco_outlined,
  'Gem': Icons.diamond_outlined,
  'Rocket': Icons.rocket_launch_outlined,
  'Sun': Icons.wb_sunny_outlined,
  'Compass': Icons.explore_outlined,
  'Library': Icons.local_library_outlined,
}[name];

const _bannerThemes = <String, List<Color>>{
  'ocean': [Color(0xFF0891B2), Color(0xFF2563EB), Color(0xFF0D9488)],
  'violet': [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFF4F46E5)],
  'rose': [Color(0xFFE11D48), Color(0xFFDB2777), Color(0xFFF97316)],
  'amber': [Color(0xFFD97706), Color(0xFFEA580C), Color(0xFFDC2626)],
  'emerald': [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF0891B2)],
};

/// The homepage body, built from the backend's ordered section list exactly
/// as the web app does: the Featured band (signed-out only) first, then every
/// section in the order the server sent, de-duplicated top to bottom.
List<Widget> _homeSections(
  HomeSnapshot snapshot, {
  required bool signedIn,
  required List<_ContinueEntry> continueEntries,
  required List<StorySummary> forYou,
  required VoidCallback onSurprise,
}) {
  final rails = _RailDedup()
    // The reader's own queue is claimed first.
    ..reserve(continueEntries.map((entry) => entry.story.slug));

  final widgets = <Widget>[];
  Widget padded(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 32), child: child);

  if (!signedIn) {
    final daily = snapshot.dailyItem;
    final items = daily != null ? [daily] : snapshot.featuredItems;
    for (final item in items) {
      rails.reserve([item.story?.slug, item.video?.story?.slug]);
    }
    if (items.isNotEmpty) {
      widgets.add(
        padded(
          _FeaturedBand(
            items: items,
            isDaily: daily != null,
            reason: daily != null ? snapshot.dailyReason : '',
          ),
        ),
      );
    }
  }

  for (final section in snapshot.sections) {
    final widget = _buildSection(
      section,
      snapshot: snapshot,
      signedIn: signedIn,
      continueEntries: continueEntries,
      forYou: forYou,
      rails: rails,
      onSurprise: onSurprise,
    );
    if (widget == null) continue;
    // The continue rail scrolls edge to edge, so it pads itself.
    widgets.add(
      section.type == 'continue_shelf'
          ? Padding(padding: const EdgeInsets.only(bottom: 32), child: widget)
          : padded(widget),
    );
  }

  if (snapshot.sections.isEmpty && widgets.isEmpty) {
    widgets.add(
      const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            "We couldn't load today's stories. Pull down to refresh.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedForeground),
          ),
        ),
      ),
    );
  }
  return [const SizedBox(height: 4), ...widgets, const SizedBox(height: 16)];
}

Widget? _buildSection(
  HomeSection section, {
  required HomeSnapshot snapshot,
  required bool signedIn,
  required List<_ContinueEntry> continueEntries,
  required List<StorySummary> forYou,
  required _RailDedup rails,
  required VoidCallback onSurprise,
}) {
  switch (section.type) {
    case 'continue_shelf':
      if (!signedIn || continueEntries.isEmpty) return null;
      return _ContinueRail(
        entries: continueEntries,
        title: section.title.isEmpty ? null : section.title,
      );
    case 'reading_journey':
      return null; // Folded into the continue row on the web too.
    case 'recommended':
      if (!signedIn) return null;
      final stories = section.allowRepeats
          ? forYou.take(section.itemLimit).toList()
          : rails.claim(forYou, limit: section.itemLimit);
      if (stories.isEmpty) return null;
      return _SectionBlock(
        title: section.title.isEmpty ? 'Picked for You' : section.title,
        icon: _sectionIcon(section.icon) ?? Icons.favorite_border,
        subtitle: section.subtitle,
        seeAllUrl: section.seeAllUrl,
        seeAllLabel: section.seeAllLabel,
        child: _StoryCards(stories: stories, section: section),
      );
    case 'journeys_banner':
      return const _PromoBanner(
        colors: [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFF4F46E5)],
        icon: Icons.route,
        title: 'Story Journeys',
        description: 'Curated paths through countries, genres, and themes.',
        action: 'Explore journeys',
        route: '/journeys',
      );
    case 'explore_tiles':
      return _ExploreTiles(
        title: section.title.isEmpty ? 'Explore' : section.title,
        onSurprise: onSurprise,
      );
    case 'new_entries':
      final stories = snapshot.newTrending.take(4).toList();
      if (stories.isEmpty) return null;
      return _SectionBlock(
        title: section.title.isEmpty ? 'New Entries' : section.title,
        icon: _sectionIcon(section.icon) ?? Icons.rss_feed,
        subtitle: section.subtitle,
        seeAllUrl: section.seeAllUrl,
        seeAllLabel: section.seeAllLabel,
        child: _StoryCards(stories: stories, section: section),
      );
    case 'ad_slot':
      return null; // No ad inventory in the app.
    case 'banner':
      final config = section.config;
      final theme = _bannerThemes[config['theme']] ?? _bannerThemes['ocean']!;
      final label = config['button_label'] as String?;
      final route = _mobileRoute(config['button_url'] as String? ?? '');
      final hasButton = label != null && label.isNotEmpty && route != null;
      return _PromoBanner(
        colors: theme,
        icon: _sectionIcon(section.icon) ?? Icons.public,
        title: section.title,
        description: section.subtitle,
        action: hasButton ? label : null,
        route: hasButton ? route : null,
      );
    case 'videos':
      if (section.videos.isEmpty) return null;
      // A video on screen reserves its story so a story rail below does not
      // offer it again.
      rails.reserve(section.videos.map((video) => video.story?.slug));
      return _SectionBlock(
        title: section.title,
        icon: _sectionIcon(section.icon),
        subtitle: section.subtitle,
        seeAllUrl: section.seeAllUrl,
        seeAllLabel: section.seeAllLabel,
        child: _CardLayout<WatchVideo>(
          items: section.videos,
          columns: section.columnsMobile.clamp(1, 2),
          rail: section.layout == 'rail',
          railHeight: (w) => w * 9 / 16 + 76,
          builder: (video) => VideoCard(video: video),
        ),
      );
    case 'blogs':
      if (section.blogs.isEmpty) return null;
      return _SectionBlock(
        title: section.title,
        icon: _sectionIcon(section.icon),
        subtitle: section.subtitle,
        seeAllUrl: section.seeAllUrl,
        seeAllLabel: section.seeAllLabel,
        child: _CardLayout<BlogSummary>(
          items: section.blogs,
          columns: section.columnsMobile.clamp(1, 2),
          rail: section.layout == 'rail',
          railHeight: (w) => w * 9 / 16 + 112,
          builder: (blog) => _BlogCard(blog: blog),
        ),
      );
    case 'stories_query':
    case 'stories_manual':
      final stories = section.allowRepeats
          ? section.stories.take(section.itemLimit).toList()
          : rails.claim(section.stories, limit: section.itemLimit);
      if (stories.isEmpty) return null;
      if (section.variant == 'originals') {
        return _OriginalsSection(
          stories: stories,
          title: section.title,
          description: section.subtitle,
          seeAllUrl: section.seeAllUrl,
          seeAllLabel: section.seeAllLabel,
        );
      }
      final icon =
          _sectionIcon(section.icon) ??
          (section.variant == 'quick_read' ? FormatIcons.quickRead : null);
      return _SectionBlock(
        title: section.title,
        icon: icon,
        subtitle: section.subtitle,
        seeAllUrl: section.seeAllUrl,
        seeAllLabel: section.seeAllLabel,
        child: section.layout == 'trending'
            ? _TrendingList(stories: stories)
            : _StoryCards(stories: stories, section: section),
      );
    default:
      // A section type from a newer backend than this build knows: skip it.
      return null;
  }
}

/// A titled section with the backend's subtitle and "See all" pill.
class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.child,
    this.icon,
    this.subtitle = '',
    this.seeAllUrl = '',
    this.seeAllLabel = 'See all',
  });
  final String title;
  final IconData? icon;
  final String subtitle;
  final String seeAllUrl;
  final String seeAllLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = _mobileRoute(seeAllUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 22, color: AppTheme.primary),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (route != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _SeeAllPill(
                  label: seeAllLabel,
                  onTap: () => context.push(route),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _SeeAllPill extends StatelessWidget {
  const _SeeAllPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 12, color: AppTheme.primary),
        ],
      ),
    ),
  );
}

/// Lays any list of cards out as the grid or scrolling rail the section asks
/// for (`layout`, `columns_mobile`).
class _CardLayout<T> extends StatelessWidget {
  const _CardLayout({
    required this.items,
    required this.columns,
    required this.rail,
    required this.railHeight,
    required this.builder,
  });
  final List<T> items;
  final int columns;
  final bool rail;
  final double Function(double itemWidth) railHeight;
  final Widget Function(T item) builder;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final available = constraints.maxWidth;
      if (rail) {
        // A sliver of the next card shows so it reads as scrollable.
        final width = (available - _gap * (columns - 1)) / (columns + 0.25);
        return SizedBox(
          height: railHeight(width),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, index) =>
                SizedBox(width: width, child: builder(items[index])),
          ),
        );
      }
      final rows = (items.length + columns - 1) ~/ columns;
      return Column(
        children: [
          for (var row = 0; row < rows; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: row * columns + col < items.length
                          ? builder(items[row * columns + col])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _StoryCards extends StatelessWidget {
  const _StoryCards({required this.stories, required this.section});
  final List<StorySummary> stories;
  final HomeSection section;

  @override
  Widget build(BuildContext context) => _CardLayout<StorySummary>(
    items: stories,
    columns: section.columnsMobile,
    rail: section.layout == 'rail',
    railHeight: (w) => w * 4 / 3 + 52,
    builder: (story) => _GridStoryCard(story: story),
  );
}

/// The "trending" layout: a ranked list inside a card.
class _TrendingList extends StatelessWidget {
  const _TrendingList({required this.stories});
  final List<StorySummary> stories;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Column(
      children: [
        for (var i = 0; i < stories.length; i++)
          InkWell(
            onTap: stories[i].slug.isEmpty
                ? null
                : () => context.push('/story/${stories[i].slug}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _StoryCover(story: stories[i]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stories[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (stories[i].author != null)
                          Text(
                            stories[i].author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _BlogCard extends StatelessWidget {
  const _BlogCard({required this.blog});
  final BlogSummary blog;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => context.push('/blog/${blog.slug}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: blog.coverImage == null || blog.coverImage!.isEmpty
                ? const ColoredBox(
                    color: AppTheme.muted,
                    child: Center(child: Icon(Icons.article_outlined)),
                  )
                : CachedAppImage(imageUrl: blog.coverImage!),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          blog.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (blog.excerpt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              blog.excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.mutedForeground,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}

/// The signed-out showcase: today's pick, or the editors' featured lineup
/// (stories and videos together).
class _FeaturedBand extends StatelessWidget {
  const _FeaturedBand({
    required this.items,
    required this.isDaily,
    required this.reason,
  });
  final List<FeaturedItem> items;
  final bool isDaily;
  final String reason;

  @override
  Widget build(BuildContext context) => _SectionBlock(
    title: isDaily ? 'Daily Story' : 'Featured Stories',
    icon: Icons.auto_awesome,
    subtitle: reason,
    child: _CardLayout<FeaturedItem>(
      items: items,
      columns: 2,
      rail: false,
      railHeight: (w) => w,
      builder: (item) => item.video != null
          ? VideoCard(video: item.video!)
          : _GridStoryCard(story: item.story!),
    ),
  );
}

/// Four ways into the catalogue, like the web's Explore tiles.
class _ExploreTiles extends StatelessWidget {
  const _ExploreTiles({required this.title, required this.onSurprise});
  final String title;
  final VoidCallback onSurprise;

  @override
  Widget build(BuildContext context) {
    final tiles = <(IconData, String, String, VoidCallback)>[
      (
        Icons.route,
        'Story Journeys',
        'Curated paths through countries, genres and themes',
        () => context.push('/journeys'),
      ),
      (
        Icons.map_outlined,
        'Story Map',
        'Follow a story back to where it comes from',
        () => context.push('/story-map'),
      ),
      (
        Icons.casino_outlined,
        'Surprise Me',
        'One story, picked for you',
        onSurprise,
      ),
      (
        Icons.mood,
        'Pick a mood',
        'Choose a feeling instead of a genre',
        () => context.push('/moods'),
      ),
    ];
    return _SectionBlock(
      title: title,
      child: _CardLayout<(IconData, String, String, VoidCallback)>(
        items: tiles,
        columns: 2,
        rail: false,
        railHeight: (w) => w,
        builder: (tile) => Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: const BorderSide(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tile.$4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Icon(tile.$1, size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tile.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tile.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
