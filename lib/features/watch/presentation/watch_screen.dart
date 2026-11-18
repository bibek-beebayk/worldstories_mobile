import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error_view.dart';
import '../../../core/app_theme.dart';
import '../data/watch_repository.dart';
import 'video_card.dart';

/// The `/watch` hub: every standalone video, filterable by type and search.
class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({super.key});

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _videos = <WatchVideo>[];

  String _search = '';
  int? _videoTypeId;
  int _page = 0;
  int _pages = 1;
  int _count = 0;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;
  int _generation = 0;

  bool get _hasMore => _page < _pages;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) _loadMore();
  }

  /// If the list is too short to scroll, the scroll listener never fires, so
  /// keep loading until the viewport is filled.
  void _checkFill() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _onScroll();
  });

  /// Fetches page 1. Existing results stay on screen until the new ones land.
  Future<void> _loadFirstPage() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final result = await ref
          .read(watchRepositoryProvider)
          .fetchVideos(
            page: 1,
            search: _search,
            videoTypeId: _videoTypeId,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _videos
          ..clear()
          ..addAll(result.videos);
        _page = result.page;
        _pages = result.pages;
        _count = result.count;
        _loading = false;
      });
      _checkFill();
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(watchRepositoryProvider)
          .fetchVideos(
            page: _page + 1,
            search: _search,
            videoTypeId: _videoTypeId,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        final known = {for (final v in _videos) v.id};
        _videos.addAll(result.videos.where((v) => !known.contains(v.id)));
        _page = result.page;
        _pages = result.pages;
        _count = result.count;
        _loadingMore = false;
      });
      _checkFill();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      // Stop auto-retrying in a tight loop; pull-to-refresh recovers.
      setState(() {
        _loadingMore = false;
        _pages = _page;
      });
    }
  }

  void _applySearch() {
    final value = _searchController.text.trim();
    if (value == _search) return;
    _search = value;
    _loadFirstPage();
  }

  void _selectType(int? id) {
    if (id == _videoTypeId) return;
    _videoTypeId = id;
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(videoTypesProvider).value ?? const <VideoType>[];
    final filtered = _search.isNotEmpty || _videoTypeId != null;
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 2 : 1;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(videoTypesProvider);
            await _loadFirstPage();
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(child: _filters(context)),
              if (types.isNotEmpty)
                SliverToBoxAdapter(child: _typeChips(types)),
              ..._body(context, columns, filtered),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Watch',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Animated narrations and more — sit back and watch.',
          style: TextStyle(color: AppTheme.mutedForeground),
        ),
      ],
    ),
  );

  Widget _filters(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.muted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.smart_display_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_count',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applySearch(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search videos...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _applySearch();
                      },
                    ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _typeChips(List<VideoType> types) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _chip('All', _videoTypeId == null, () => _selectType(null)),
        for (final type in types)
          _chip(
            type.name,
            _videoTypeId == type.id,
            () => _selectType(type.id),
          ),
      ],
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );

  List<Widget> _body(BuildContext context, int columns, bool filtered) {
    if (_videos.isEmpty) {
      if (_loading) {
        return const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ];
      }
      if (_error != null) {
        return [
          SliverToBoxAdapter(
            child: ApiErrorView(error: _error!, onRetry: _loadFirstPage),
          ),
        ];
      }
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Text(
                filtered
                    ? 'No videos match your filters.'
                    : 'No videos available yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.mutedForeground),
              ),
            ),
          ),
        ),
      ];
    }

    final rowCount = (_videos.length + columns - 1) ~/ columns;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: rowCount,
          itemBuilder: (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 16),
                  Expanded(
                    child: row * columns + col < _videos.length
                        ? VideoCard(video: _videos[row * columns + col])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: _loadingMore
                ? const Text(
                    'Loading more…',
                    style: TextStyle(color: AppTheme.mutedForeground),
                  )
                : !_hasMore
                ? const Text(
                    "You've reached the end.",
                    style: TextStyle(color: AppTheme.mutedForeground),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }
}
