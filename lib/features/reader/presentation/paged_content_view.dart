import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Shows [child] (a tall column of rendered text) as horizontally swiped
/// pages, for the reader's page view.
///
/// Rather than re-implementing text layout, [child] is laid out once
/// off-screen at the page width, and every line box and image in it is
/// measured. Page breaks are then placed between lines — never through one —
/// and each page shows its slice of that same layout, clipped. Any content
/// the scroll view can render therefore paginates identically, keeping all
/// HTML styling.
class PagedContentView extends StatefulWidget {
  const PagedContentView({
    super.key,
    required this.child,
    required this.padding,
    required this.onProgress,
    this.maxWidth = 720,
    this.pinching = false,
    this.initialFraction = 0,
  });

  final Widget child;

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
  final _controller = PageController();
  List<_Slice> _pages = const [];
  int _current = 0;
  double? _pendingFraction;
  double _pageHeight = 0;
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
    _pendingFraction = fraction.clamp(0.0, 1.0);
    _schedulePagination();
  }

  void _schedulePagination() {
    if (_paginationScheduled) return;
    _paginationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationScheduled = false;
      if (mounted) _paginate();
    });
    // A post-frame callback alone doesn't cause a frame (e.g. a restore
    // arriving while the page is idle), so ask for one.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _paginate() {
    final root = _measureKey.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize || _pageHeight <= 0) return;
    final pages = _computePages(root, _pageHeight);
    final changed =
        pages.length != _pages.length ||
        pages.indexed.any(
          (entry) =>
              (entry.$2.top - _pages[entry.$1].top).abs() > 0.5 ||
              (entry.$2.bottom - _pages[entry.$1].bottom).abs() > 0.5,
        );
    if (!changed && _pendingFraction == null) return;

    // Keep the reader at the same point through a re-layout (text size,
    // font or rotation change), or go where we were asked to.
    final fraction =
        _pendingFraction ??
        (_pages.length <= 1 ? 0.0 : _current / (_pages.length - 1));
    _pendingFraction = null;
    final target = (fraction * (pages.length - 1)).round().clamp(
      0,
      pages.length - 1,
    );
    setState(() {
      _pages = pages;
      _current = target;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients && _controller.page?.round() != target) {
        _controller.jumpToPage(target);
      }
      widget.onProgress(_fractionOf(target));
    });
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(
        widget.maxWidth,
        constraints.maxWidth - widget.padding.horizontal,
      );
      final pageHeight = constraints.maxHeight - widget.padding.vertical;
      if (pageHeight != _pageHeight) _pageHeight = pageHeight;
      // Re-measure after every rebuild; it's a no-op when nothing moved.
      _schedulePagination();
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
                    child: KeyedSubtree(key: _measureKey, child: widget.child),
                  ),
                ),
              ),
            ),
          ),
          PageView.builder(
            controller: _controller,
            physics: widget.pinching
                ? const NeverScrollableScrollPhysics()
                // Always scrollable so a one-page chapter can still be
                // swiped past its ends (see the reader's chapter hand-off).
                : const PageScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
            itemCount: _pages.length,
            onPageChanged: (page) {
              _current = page;
              widget.onProgress(_fractionOf(page));
            },
            itemBuilder: (context, index) {
              final slice = _pages[index];
              return Padding(
                padding: EdgeInsets.only(
                  top: widget.padding.top,
                  bottom: widget.padding.bottom,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    height: slice.bottom - slice.top,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: width,
                        maxWidth: width,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: Transform.translate(
                          offset: Offset(0, -slice.top),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}
