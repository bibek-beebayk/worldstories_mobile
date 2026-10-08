import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../shared/widgets/quick_page_physics.dart';

/// Shows [children] (the blocks of a section — paragraphs, headings,
/// images — stacked top to bottom) as horizontally swiped pages, for the
/// reader's page view.
///
/// Rather than re-implementing text layout, the blocks are laid out once
/// off-screen at the page width, and every line box and image in them is
/// measured. Page breaks are then placed between lines — never through one.
/// Each page then builds only the blocks that appear on it, positioned
/// exactly as measured and clipped to the page, so turning a page costs a
/// page's worth of layout rather than the whole section's.
class PagedContentView extends StatefulWidget {
  const PagedContentView({
    super.key,
    required this.children,
    required this.padding,
    required this.onProgress,
    this.layoutKey,
    this.maxWidth = 720,
    this.pinching = false,
    this.initialFraction = 0,
  });

  final List<Widget> children;

  /// Changes whenever the blocks' layout may change (text size, font,
  /// section), telling the view to re-measure. Other rebuilds (theme,
  /// chrome) skip the measuring.
  final Object? layoutKey;

  /// Space around each page's text (e.g. clear of the floating reader bars).
  final EdgeInsets padding;

  /// Reports how far through the content the current page is (0–1).
  final ValueChanged<double> onProgress;
  final double maxWidth;

  /// Freezes swiping while two fingers resize the text.
  final bool pinching;

  /// Where to open, as a fraction of the content (e.g. restored progress).
  final double initialFraction;

  @override
  PagedContentViewState createState() => PagedContentViewState();
}

typedef _Slice = ({double top, double bottom});

class PagedContentViewState extends State<PagedContentView> {
  final _measureKey = GlobalKey();
  List<GlobalKey> _blockKeys = const [];
  final _controller = PageController();
  final _swipe = PageSwipeTracker();
  List<_Slice> _pages = const [];

  /// Each block's measured vertical extent, in content coordinates.
  List<_Slice> _blocks = const [];
  int _current = 0;
  double? _pendingFraction;
  double _pageHeight = 0;
  double _width = 0;
  Object? _measuredFor;
  bool _paginationScheduled = false;

  @override
  void initState() {
    super.initState();
    _pendingFraction = widget.initialFraction;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get pageCount => _pages.length;
  int get currentPage => _current;
  bool get isFirstPage => _current <= 0;
  bool get isLastPage => _current >= _pages.length - 1;

  double _fractionOf(int page) =>
      _pages.length <= 1 ? 1 : page / (_pages.length - 1);

  void nextPage() {
    if (isLastPage) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void previousPage() {
    if (isFirstPage) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Opens the page at [fraction] of the content, once pages are known.
  void jumpToFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    if (_pages.isEmpty) {
      _pendingFraction = clamped;
      return;
    }
    _goTo((clamped * (_pages.length - 1)).round());
  }

  void _goTo(int page) {
    final target = page.clamp(0, math.max(0, _pages.length - 1)).toInt();
    if (_current != target) setState(() => _current = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients && _controller.page?.round() != target) {
        _controller.jumpToPage(target);
      }
      widget.onProgress(_fractionOf(target));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _schedulePagination() {
    if (_paginationScheduled) return;
    _paginationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationScheduled = false;
      if (mounted) _paginate();
    });
    // A post-frame callback alone doesn't cause a frame, so ask for one.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _paginate() {
    final root = _measureKey.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize || _pageHeight <= 0) return;
    final pages = _computePages(root, _pageHeight);
    final blocks = [
      for (final key in _blockKeys)
        switch (key.currentContext?.findRenderObject()) {
          final RenderBox box when box.hasSize => (
            top: box.localToGlobal(Offset.zero, ancestor: root).dy,
            bottom:
                box.localToGlobal(Offset.zero, ancestor: root).dy +
                box.size.height,
          ),
          _ => (top: 0.0, bottom: 0.0),
        },
    ];
    // Keep the reader at the same point through a re-layout (text size,
    // font or rotation change), or go where we were asked to.
    final fraction =
        _pendingFraction ??
        (_pages.length <= 1 ? 0.0 : _current / (_pages.length - 1));
    _pendingFraction = null;
    setState(() {
      _pages = pages;
      _blocks = blocks;
    });
    _goTo((fraction * (pages.length - 1)).round());
  }

  /// Unbreakable vertical bands (text lines, images) in [root]'s layout,
  /// then pages that each end at the last band that fits.
  static List<_Slice> _computePages(RenderBox root, double pageHeight) {
    final bands = <_Slice>[];

    void add(double top, double bottom) {
      if (bottom > top) bands.add((top: top, bottom: bottom));
    }

    void visit(RenderObject object) {
      if (object is RenderParagraph && object.hasSize) {
        final origin = object.localToGlobal(Offset.zero, ancestor: root).dy;
        // Inline widgets (nested blocks) appear as U+FFFC placeholders;
        // measure only real text here, nested paragraphs are visited below.
        final text = object.text.toPlainText();
        var start = 0;
        for (var i = 0; i <= text.length; i++) {
          if (i == text.length || text.codeUnitAt(i) == 0xFFFC) {
            if (i > start) {
              for (final box in object.getBoxesForSelection(
                TextSelection(baseOffset: start, extentOffset: i),
              )) {
                add(origin + box.top, origin + box.bottom);
              }
            }
            start = i + 1;
          }
        }
      } else if (object is RenderImage && object.hasSize) {
        final top = object.localToGlobal(Offset.zero, ancestor: root).dy;
        add(top, top + object.size.height);
      }
      object.visitChildren(visit);
    }

    visit(root);
    bands.sort((a, b) => a.top.compareTo(b.top));

    // Merge boxes on the same line into one band.
    final merged = <_Slice>[];
    for (final band in bands) {
      if (merged.isNotEmpty && band.top < merged.last.bottom - 0.5) {
        final last = merged.removeLast();
        merged.add((top: last.top, bottom: math.max(last.bottom, band.bottom)));
      } else {
        merged.add(band);
      }
    }

    final total = root.size.height;
    if (merged.isEmpty) return [(top: 0, bottom: math.min(total, pageHeight))];

    final pages = <_Slice>[];
    final count = merged.length;
    var top = 0.0;
    var index = 0;
    while (true) {
      // Drop bands already shown.
      while (index < count && merged[index].bottom <= top + 0.5) {
        index++;
      }
      if (index >= count) break;
      // Start the page at its first line, skipping blank margin (unless
      // we're continuing inside a band taller than a page).
      if (merged[index].top > top) top = merged[index].top;
      final limit = top + pageHeight;
      var next = index;
      while (next < count && merged[next].bottom <= limit) {
        next++;
      }
      final double cut;
      if (next >= count || merged[next].top >= limit) {
        cut = math.min(limit, total);
      } else if (merged[next].top > top + 1) {
        // The first line that doesn't fully fit starts the next page.
        cut = merged[next].top;
      } else {
        // A single band taller than a page (a huge image) gets cut.
        cut = limit;
      }
      pages.add((top: top, bottom: cut));
      top = cut;
    }
    if (pages.isEmpty) pages.add((top: 0, bottom: math.min(total, pageHeight)));
    return pages;
  }

  Widget _page(_Slice slice) => SizedBox(
    width: _width,
    height: slice.bottom - slice.top,
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (var i = 0; i < _blocks.length && i < widget.children.length; i++)
          if (_blocks[i].bottom > slice.top && _blocks[i].top < slice.bottom)
            Positioned(
              top: _blocks[i].top - slice.top,
              left: 0,
              width: _width,
              child: widget.children[i],
            ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(
        widget.maxWidth,
        constraints.maxWidth - widget.padding.horizontal,
      );
      final pageHeight = constraints.maxHeight - widget.padding.vertical;
      if (_blockKeys.length != widget.children.length) {
        _blockKeys = [for (final _ in widget.children) GlobalKey()];
      }
      // Re-measure only when something that moves text changed.
      final measureFor = (
        widget.layoutKey,
        width,
        pageHeight,
        widget.children.length,
      );
      if (measureFor != _measuredFor) {
        _measuredFor = measureFor;
        _width = width;
        _pageHeight = pageHeight;
        _schedulePagination();
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          // The measured copy. Offstage still lays it out.
          Offstage(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: width,
              maxWidth: width,
              minHeight: 0,
              maxHeight: double.infinity,
              child: NotificationListener<SizeChangedLayoutNotification>(
                // Images load after the first layout and push text down.
                onNotification: (_) {
                  _schedulePagination();
                  return true;
                },
                child: SizeChangedLayoutNotifier(
                  // Hidden copy: keep it out of text selection.
                  child: SelectionContainer.disabled(
                    child: Column(
                      key: _measureKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < widget.children.length; i++)
                          KeyedSubtree(
                            key: _blockKeys[i],
                            child: widget.children[i],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) {
                _swipe.originPage = _controller.page?.round() ?? _current;
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              // Same quick swipe as the story list: a short drag or a light
              // flick turns the page.
              pageSnapping: false,
              physics: widget.pinching
                  ? const NeverScrollableScrollPhysics()
                  // Always scrollable so a one-page section can still be
                  // swiped past its ends (see the reader's section hand-off).
                  : QuickPageScrollPhysics(
                      tracker: _swipe,
                      parent: const AlwaysScrollableScrollPhysics(),
                    ),
              itemCount: _pages.length,
              onPageChanged: (page) {
                _current = page;
                widget.onProgress(_fractionOf(page));
              },
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  top: widget.padding.top,
                  bottom: widget.padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  // Each page paints once and is then cached while it slides.
                  child: RepaintBoundary(child: _page(_pages[index])),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
