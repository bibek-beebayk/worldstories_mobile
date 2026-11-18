import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error_view.dart';
import '../../../core/app_theme.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/cached_app_image.dart';
import '../../../shared/widgets/quick_page_physics.dart';
import '../../home/data/home_repository.dart';
import '../data/catalogue_repository.dart';
import '../../../core/format_icons.dart';

final catalogueRepositoryProvider = Provider<CatalogueRepository>(
  (ref) => CatalogueRepository(ref.watch(apiClientProvider)),
);
final catalogueFiltersProvider = FutureProvider<CatalogueFilters>(
  (ref) => ref.watch(catalogueRepositoryProvider).fetchFilters(),
);

enum _LibraryMode { read, listen, readAlong, quickRead }

extension on _LibraryMode {
  String get label => switch (this) {
    _LibraryMode.read => 'Read',
    _LibraryMode.listen => 'Listen',
    _LibraryMode.readAlong => 'Read Along',
    _LibraryMode.quickRead => 'Quick Read',
  };

  IconData get icon => switch (this) {
    _LibraryMode.read => FormatIcons.read,
    _LibraryMode.listen => FormatIcons.listen,
    _LibraryMode.readAlong => FormatIcons.readAlong,
    _LibraryMode.quickRead => FormatIcons.quickRead,
  };
}

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key, this.initialMoodSlugs = ''});

  final String initialMoodSlugs;

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  static const _storiesPerPage = 9;
  final search = TextEditingController();
  final pageController = PageController();
  final pageSwipeTracker = PageSwipeTracker();
  final stories = <StorySummary>[];
  bool searchVisible = false;
  bool initialLoading = true;
  bool loadingMore = false;
  Object? initialError;
  Object? loadMoreError;
  int page = 0;
  int pages = 1;
  int totalCount = 0;
  int visiblePage = 0;
  int targetPageToLoad = 0;
  bool ensuringPages = false;
  int loadGeneration = 0;
  String sort = 'recent';
  _LibraryMode libraryMode = _LibraryMode.read;
  Set<int> genres = {};
  Set<int> categories = {};
  late Set<String> moodSlugs;
  String language = 'all';
  String country = 'all';
  String storyType = 'all';
  String status = 'all';

  int get uiPageCount => (totalCount + _storiesPerPage - 1) ~/ _storiesPerPage;

  @override
  void initState() {
    super.initState();
    moodSlugs = _parseMoodSlugs(widget.initialMoodSlugs);
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void didUpdateWidget(covariant CatalogueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMoodSlugs == widget.initialMoodSlugs) return;
    moodSlugs = _parseMoodSlugs(widget.initialMoodSlugs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    search.dispose();
    pageController.dispose();
    super.dispose();
  }

  CatalogueQuery _queryFor(int requestedPage) => CatalogueQuery(
    page: requestedPage,
    search: search.text.trim(),
    sort: sort,
    hasAudio: libraryMode == _LibraryMode.listen,
    hasSummary: libraryMode == _LibraryMode.quickRead,
    hasReadAlong: libraryMode == _LibraryMode.readAlong,
    genreIds: {...genres},
    categoryIds: {...categories},
    moodSlugs: {...moodSlugs},
    language: language,
    country: country,
    storyType: storyType,
    status: status,
  );

  Future<void> refresh() async {
    final generation = ++loadGeneration;
    setState(() {
      initialLoading = true;
      loadingMore = false;
      initialError = null;
      loadMoreError = null;
      page = 0;
      pages = 1;
      totalCount = 0;
      visiblePage = 0;
      targetPageToLoad = 0;
      stories.clear();
    });
    try {
      final result = await ref
          .read(catalogueRepositoryProvider)
          .fetch(_queryFor(1));
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        stories.addAll(result.stories);
        page = result.page;
        pages = result.pages;
        totalCount = result.count;
        initialLoading = false;
      });
      if (pageController.hasClients) pageController.jumpToPage(0);
      if (uiPageCount > 1) _ensureStoriesForPage(1);
    } catch (error) {
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        initialError = error;
        initialLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (initialLoading || loadingMore || page >= pages) return;
    final generation = loadGeneration;
    final requestedPage = page + 1;
    setState(() {
      loadingMore = true;
      loadMoreError = null;
    });
    try {
      final result = await ref
          .read(catalogueRepositoryProvider)
          .fetch(_queryFor(requestedPage));
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        stories.addAll(result.stories);
        page = result.page;
        pages = result.pages;
        totalCount = result.count;
        loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        loadMoreError = error;
        loadingMore = false;
      });
    }
  }

  Future<void> _ensureStoriesForPage(int pageIndex) async {
    if (pageIndex > targetPageToLoad) targetPageToLoad = pageIndex;
    if (initialLoading || ensuringPages) return;
    ensuringPages = true;
    try {
      while (mounted) {
        final requiredStories = ((targetPageToLoad + 1) * _storiesPerPage)
            .clamp(0, totalCount);
        if (stories.length >= requiredStories || page >= pages) return;
        await _loadNextPage();
        if (loadMoreError != null) return;
      }
    } finally {
      ensuringPages = false;
    }
  }

  void toggleSearch() {
    setState(() => searchVisible = !searchVisible);
    if (!searchVisible) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> showFilters() async {
    final result = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CatalogueFilterSheet(
        initial: _FilterSelection(
          genres: genres,
          categories: categories,
          language: language,
          country: country,
          storyType: storyType,
          status: status,
        ),
      ),
    );
    if (result == null) return;
    genres = result.genres;
    categories = result.categories;
    language = result.language;
    country = result.country;
    storyType = result.storyType;
    status = result.status;
    refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Library'),
      actions: [
        IconButton(
          onPressed: toggleSearch,
          icon: Icon(searchVisible ? Icons.close : Icons.search),
          tooltip: searchVisible ? 'Close search' : 'Search',
        ),
        IconButton(
          onPressed: showFilters,
          icon: const Icon(Icons.tune),
          tooltip: 'More filters',
        ),
      ],
    ),
    body: Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          reverseDuration: const Duration(milliseconds: 160),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
          child: searchVisible
              ? Padding(
                  key: const ValueKey('library-search'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: TextField(
                        controller: search,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => refresh(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search stories…',
                          suffixIcon: IconButton(
                            onPressed: refresh,
                            icon: const Icon(Icons.arrow_forward),
                            tooltip: 'Search',
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('library-search-hidden')),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.only(left: 12, right: 7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: sort,
                  isDense: true,
                  borderRadius: BorderRadius.circular(10),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 19),
                  items: const [
                    DropdownMenuItem(value: 'recent', child: Text('Recent')),
                    DropdownMenuItem(value: 'rating', child: Text('Top rated')),
                    DropdownMenuItem(
                      value: 'views',
                      child: Text('Most viewed'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null && value != sort) {
                      sort = value;
                      refresh();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              ..._LibraryMode.values.map(
                (mode) => _LibraryModeChip(
                  label: mode.label,
                  icon: mode.icon,
                  selected: libraryMode == mode,
                  onSelected: () {
                    if (libraryMode == mode) return;
                    libraryMode = mode;
                    refresh();
                  },
                ),
              ),
              ...moodSlugs.map(
                (mood) => _FilterChip(
                  label: _moodLabel(mood),
                  selected: true,
                  onSelected: (_) => context.go('/library'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: initialLoading
              ? const Center(child: CircularProgressIndicator())
              : initialError != null
              ? ApiErrorView(error: initialError!, onRetry: refresh)
              : stories.isEmpty
              ? const Center(child: Text('No stories found.'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            '$totalCount stories',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Text(
                            'Page ${visiblePage + 1} of '
                            '$uiPageCount',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollStartNotification>(
                        onNotification: (notification) {
                          if (notification.dragDetails != null) {
                            pageSwipeTracker.originPage =
                                pageController.page?.round() ?? visiblePage;
                          }
                          return false;
                        },
                        child: PageView.builder(
                          controller: pageController,
                          pageSnapping: false,
                          physics: QuickPageScrollPhysics(
                            tracker: pageSwipeTracker,
                          ),
                          itemCount: uiPageCount,
                          onPageChanged: (index) {
                            setState(() => visiblePage = index);
                            final nextPage = index + 1;
                            _ensureStoriesForPage(
                              nextPage < uiPageCount ? nextPage : index,
                            );
                          },
                          itemBuilder: (context, pageIndex) =>
                              _CataloguePageGrid(
                                pageIndex: pageIndex,
                                stories: stories,
                                totalCount: totalCount,
                                loading: loadingMore,
                                failed: loadMoreError != null,
                                onLoad: () => _ensureStoriesForPage(pageIndex),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

Set<String> _parseMoodSlugs(String value) => value
    .split(',')
    .map((slug) => slug.trim())
    .where((slug) => slug.isNotEmpty)
    .toSet();

String _moodLabel(String slug) => slug
    .split('-')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

class _CataloguePageGrid extends StatefulWidget {
  const _CataloguePageGrid({
    required this.pageIndex,
    required this.stories,
    required this.totalCount,
    required this.loading,
    required this.failed,
    required this.onLoad,
  });

  final int pageIndex;
  final List<StorySummary> stories;
  final int totalCount;
  final bool loading;
  final bool failed;
  final VoidCallback onLoad;

  @override
  State<_CataloguePageGrid> createState() => _CataloguePageGridState();
}

class _CataloguePageGridState extends State<_CataloguePageGrid> {
  bool loadRequested = false;

  @override
  void didUpdateWidget(covariant _CataloguePageGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stories.length != oldWidget.stories.length ||
        widget.failed != oldWidget.failed) {
      loadRequested = false;
    }
  }

  void _requestMissingStories(int firstIndex) {
    if (firstIndex < widget.stories.length || loadRequested) return;
    loadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    const itemsPerPage = _CatalogueScreenState._storiesPerPage;
    final firstIndex = widget.pageIndex * itemsPerPage;
    _requestMissingStories(firstIndex);
    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const verticalPadding = 8.0;
          const rowSpacing = 8.0;
          final itemHeight =
              (constraints.maxHeight - verticalPadding - rowSpacing * 2) / 3;
          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, verticalPadding),
            itemCount: itemsPerPage,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: rowSpacing,
              mainAxisExtent: itemHeight,
            ),
            itemBuilder: (context, localIndex) {
              final storyIndex = firstIndex + localIndex;
              if (storyIndex >= widget.totalCount) return const SizedBox();
              if (storyIndex < widget.stories.length) {
                return _CatalogueCard(story: widget.stories[storyIndex]);
              }
              if (storyIndex != widget.stories.length) {
                return const SizedBox();
              }
              if (widget.failed) {
                return Center(
                  child: IconButton.filledTonal(
                    onPressed: widget.onLoad,
                    tooltip: 'Retry loading page',
                    icon: const Icon(Icons.refresh),
                  ),
                );
              }
              return Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.loading
                        ? AppTheme.primary
                        : Colors.transparent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    ),
  );
}

class _LibraryModeChip extends StatelessWidget {
  const _LibraryModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: ChoiceChip(
      label: Semantics(
        label: label,
        selected: selected,
        child: Tooltip(
          message: label,
          child: Icon(icon, size: 18, color: selected ? Colors.white : null),
        ),
      ),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      onSelected: (_) => onSelected(),
    ),
  );
}

final class _FilterSelection {
  const _FilterSelection({
    required this.genres,
    required this.categories,
    required this.language,
    required this.country,
    required this.storyType,
    required this.status,
  });
  final Set<int> genres;
  final Set<int> categories;
  final String language;
  final String country;
  final String storyType;
  final String status;
}

class _CatalogueFilterSheet extends ConsumerStatefulWidget {
  const _CatalogueFilterSheet({required this.initial});
  final _FilterSelection initial;
  @override
  ConsumerState<_CatalogueFilterSheet> createState() =>
      _CatalogueFilterSheetState();
}

class _CatalogueFilterSheetState extends ConsumerState<_CatalogueFilterSheet> {
  late Set<int> genres = {...widget.initial.genres};
  late Set<int> categories = {...widget.initial.categories};
  late String language = widget.initial.language;
  late String country = widget.initial.country;
  late String storyType = widget.initial.storyType;
  late String status = widget.initial.status;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ref
          .watch(catalogueFiltersProvider)
          .when(
            loading: () => const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 240,
              child: ApiErrorView(
                error: error,
                onRetry: () => ref.invalidate(catalogueFiltersProvider),
              ),
            ),
            data: (filters) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Filter stories',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          genres.clear();
                          categories.clear();
                          language = country = storyType = status = 'all';
                        }),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        _Dropdown(
                          label: 'Language',
                          value: language,
                          options: filters.languages,
                          onChanged: (value) =>
                              setState(() => language = value),
                        ),
                        _Dropdown(
                          label: 'Country',
                          value: country,
                          options: filters.countries,
                          onChanged: (value) => setState(() => country = value),
                        ),
                        _Dropdown(
                          label: 'Story type',
                          value: storyType,
                          options: filters.storyTypes,
                          onChanged: (value) =>
                              setState(() => storyType = value),
                        ),
                        _Dropdown(
                          label: 'Status',
                          value: status,
                          options: const [
                            FilterOption(
                              value: 'completed',
                              label: 'Completed',
                            ),
                            FilterOption(value: 'ongoing', label: 'Ongoing'),
                          ],
                          onChanged: (value) => setState(() => status = value),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Genres',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: filters.genres.map((option) {
                            final id = int.parse(option.value);
                            return _CompactFilterChip(
                              label: option.label,
                              selected: genres.contains(id),
                              onSelected: (selected) => setState(
                                () => selected
                                    ? genres.add(id)
                                    : genres.remove(id),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Categories',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: filters.categories.map((option) {
                            final id = int.parse(option.value);
                            return _CompactFilterChip(
                              label: option.label,
                              selected: categories.contains(id),
                              onSelected: (selected) => setState(
                                () => selected
                                    ? categories.add(id)
                                    : categories.remove(id),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        _FilterSelection(
                          genres: genres,
                          categories: categories,
                          language: language,
                          country: country,
                          storyType: storyType,
                          status: status,
                        ),
                      ),
                      child: const Text('Apply filters'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    ),
  );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<FilterOption> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All')),
            ...options.map(
              (option) => DropdownMenuItem(
                value: option.value,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    ),
  );
}

class _CompactFilterChip extends StatelessWidget {
  const _CompactFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    selected: selected,
    onSelected: onSelected,
    showCheckmark: false,
    selectedColor: AppTheme.primary.withValues(alpha: 0.18),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
    labelPadding: const EdgeInsets.symmetric(horizontal: 5),
    padding: EdgeInsets.zero,
  );
}

class _CatalogueCard extends StatelessWidget {
  const _CatalogueCard({required this.story});
  final StorySummary story;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/story/${story.slug}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: story.coverImage == null
                    ? _Fallback(story: story)
                    : CachedAppImage(
                        imageUrl: story.coverImage!,
                        fit: BoxFit.cover,
                        error: (_) => _Fallback(story: story),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 31,
          child: Text(
            story.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontSize: 11, height: 1.2),
          ),
        ),
      ],
    ),
  );
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.story});
  final StorySummary story;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.heroDark,
          AppTheme.heroGradientEnd,
          Color(0xFF4A2030),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
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
        if (story.author != null) ...[
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
  );
}
