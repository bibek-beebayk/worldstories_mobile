import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error_view.dart';
import '../../../core/app_theme.dart';
import '../application/reader_appearance.dart';
import 'paged_content_view.dart';
import 'reader_settings_sheet.dart';

/// Lets a reader screen move the shell's view (restoring a saved position).
class ReaderShellController {
  _ReaderShellState? _state;

  /// Current position within the shown section (0–1).
  double get fraction => _state?.progress.value ?? 0;

  /// Goes to [fraction] of the shown section, once it has been laid out.
  void jumpToFraction(double fraction) => _state?._jumpToFraction(fraction);
}

/// An extra button in the reader's top bar (e.g. Quick Read).
@immutable
final class ReaderBarAction {
  const ReaderBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// The reading experience shared by the app's text readers (HTML chapters,
/// EPUB), modelled on the web reader: a themed full-screen surface with
/// floating top/bottom bars that toggle on tap, a progress hairline and
/// pill, reader settings, fullscreen, pinch-to-zoom text, scroll or page
/// layout, and continuous reading into the neighbouring section when the
/// reader pulls or swipes past either end.
///
/// The screen supplies the section's [blocks] and decides what "next" and
/// "previous" mean ([onNext]/[onPrevious]); the shell owns all the chrome
/// and gestures.
class ReaderShell extends ConsumerStatefulWidget {
  const ReaderShell({
    super.key,
    required this.controller,
    required this.sectionKey,
    required this.title,
    required this.subtitle,
    required this.bottomLabel,
    required this.overallProgress,
    required this.blocks,
    this.error,
    this.onProgress,
    this.onNext,
    this.onPrevious,
    this.drawer,
    this.actions = const [],
    this.initialFraction = 0,
    this.sectionProgressLabel = 'Chapter',
  });

  final ReaderShellController controller;

  /// Identifies the section being shown. When it changes the view resets to
  /// [initialFraction] of the new section.
  final Object sectionKey;
  final String title;
  final String subtitle;
  final String bottomLabel;

  /// Maps the position within this section (0–1) to the whole book's.
  final double Function(double sectionFraction) overallProgress;

  /// The section's content as paragraph-level blocks (see
  /// splitHtmlBlocks); null while it loads.
  final List<Widget>? blocks;
  final Object? error;
  final ValueChanged<double>? onProgress;

  /// Called when the reader pulls/swipes past the end (null: last section).
  final VoidCallback? onNext;

  /// Called when the reader pulls/swipes back past the start.
  final VoidCallback? onPrevious;
  final Widget? drawer;
  final List<ReaderBarAction> actions;

  /// Where a section opens (0 = start, 1 = end).
  final double initialFraction;

  /// Word used for the within-section percentage ("Chapter 40%").
  final String sectionProgressLabel;

  /// Shown while moving to the neighbouring section.
  static const nextLabel = 'Opening next chapter…';
  static const previousLabel = 'Opening previous chapter…';

  @override
  ConsumerState<ReaderShell> createState() => _ReaderShellState();
}

class _ReaderShellState extends ConsumerState<ReaderShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final scrollController = ScrollController();

  /// How far through the section the reader is. A notifier rather than
  /// state so scrolling only rebuilds the progress UI, not the text.
  final progress = ValueNotifier<double>(0);
  var pagedKey = GlobalKey<PagedContentViewState>();
  double? pendingFraction;
  bool? lastPaged;
  bool chromeVisible = true;
  bool immersive = false;

  /// How far the reader has pulled past either end of the section
  /// (negative = before the start). Past [_pullThreshold] the neighbouring
  /// section opens.
  double pull = 0;
  bool leavingSection = false;
  static const _pullThreshold = 72.0;

  /// Set the moment the reader asks for the neighbouring section, so there
  /// is feedback while it loads and lays out.
  String? transitionLabel;

  // A new section's blocks are built a chunk per frame, so the first
  // screenful appears at once instead of after one long frozen frame.
  static const _firstChunk = 12;
  static const _chunk = 16;
  int builtCount = 0;
  Object? builtFor;
  bool growScheduled = false;

  // Pinch-to-zoom: the live pointers and the size/distance the pinch
  // started from.
  final pointers = <int, Offset>{};
  double? pinchStartDistance;
  double? pinchStartFontSize;

  // Tap tracking (see _onPointerEnd).
  Offset? tapDownPosition;
  DateTime? tapDownTime;
  bool tapCancelled = false;

  bool get paged => ref.read(readerAppearanceProvider).paged;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    progress.value = widget.initialFraction;
    pendingFraction = widget.initialFraction > 0
        ? widget.initialFraction
        : null;
    scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ReaderShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    if (oldWidget.sectionKey != widget.sectionKey) {
      // A new section: start it fresh at its start (or end, when arriving
      // backwards).
      leavingSection = false;
      transitionLabel = null;
      pull = 0;
      pagedKey = GlobalKey<PagedContentViewState>();
      progress.value = widget.initialFraction;
      // Applied after the new section's first layout (see _applyPending).
      pendingFraction = widget.initialFraction;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    scrollController.dispose();
    progress.dispose();
    if (immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _jumpToFraction(double fraction) {
    progress.value = fraction;
    // Supersedes any position still waiting for layout.
    pendingFraction = null;
    if (paged) {
      final pages = pagedKey.currentState;
      if (pages != null) {
        pages.jumpToFraction(fraction);
      } else {
        pendingFraction = fraction;
      }
    } else if (scrollController.hasClients && _complete) {
      scrollController.jumpTo(
        scrollController.position.maxScrollExtent * fraction,
      );
    } else {
      // Not laid out yet (or still being built): jump once it all is.
      pendingFraction = fraction;
    }
  }

  bool get _complete {
    final blocks = widget.blocks;
    return blocks != null && builtCount >= blocks.length;
  }

  void _scheduleGrow() {
    if (growScheduled) return;
    growScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      growScheduled = false;
      final total = widget.blocks?.length ?? 0;
      if (!mounted || builtCount >= total) return;
      setState(() => builtCount = math.min(total, builtCount + _chunk));
    });
  }

  /// Applies a position requested before the content was laid out, once
  /// all of it is built.
  void _applyPending(bool complete) {
    final fraction = pendingFraction;
    if (fraction == null || widget.blocks == null || !complete) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || pendingFraction != fraction) return;
      if (paged) {
        // The page view opened at initialFraction already.
        pendingFraction = null;
        return;
      }
      if (!scrollController.hasClients) return;
      pendingFraction = null;
      scrollController.jumpTo(
        scrollController.position.maxScrollExtent * fraction,
      );
      _onScroll();
    });
  }

  void _onScroll() {
    if (!scrollController.hasClients || paged) return;
    final max = scrollController.position.maxScrollExtent;
    _reportProgress(
      max <= 0 ? 1 : (scrollController.offset / max).clamp(0.0, 1.0),
    );
  }

  void _reportProgress(double value) {
    progress.value = value;
    widget.onProgress?.call(value);
  }

  /// Continuous reading: dragging on past the end of a section (scrolling
  /// down, or swiping on from the last page) opens the next one, and past
  /// the start opens the previous one at its end.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || leavingSection) return false;
    final axis = paged ? Axis.horizontal : Axis.vertical;
    if (notification.metrics.axis != axis) return false;
    if (notification is ScrollStartNotification) {
      pull = 0;
    } else if (notification is OverscrollNotification) {
      // Clamping physics (Android): overscroll arrives as deltas.
      if (notification.dragDetails != null) pull += notification.overscroll;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      // Bouncing physics (iOS): the position itself runs past the ends.
      final metrics = notification.metrics;
      if (metrics.pixels > metrics.maxScrollExtent) {
        pull = metrics.pixels - metrics.maxScrollExtent;
      } else if (metrics.pixels < metrics.minScrollExtent) {
        pull = metrics.pixels - metrics.minScrollExtent;
      } else {
        pull = 0;
      }
    }
    if (pull > _pullThreshold && widget.onNext != null) {
      _goNext();
    } else if (pull < -_pullThreshold && widget.onPrevious != null) {
      _goPrevious();
    }
    return false;
  }

  void _goNext() {
    final next = widget.onNext;
    if (next == null || leavingSection) return;
    leavingSection = true;
    setState(() => transitionLabel = ReaderShell.nextLabel);
    next();
  }

  void _goPrevious() {
    final previous = widget.onPrevious;
    if (previous == null || leavingSection) return;
    leavingSection = true;
    setState(() => transitionLabel = ReaderShell.previousLabel);
    previous();
  }

  /// In page view the outer thirds of the screen turn pages (past a
  /// section's last/first page they open the neighbouring section);
  /// elsewhere a tap shows or hides the reader bars.
  void _onTap(Offset position) {
    final pages = pagedKey.currentState;
    if (paged && pages != null) {
      final width = MediaQuery.sizeOf(context).width;
      if (position.dx < width * 0.3) {
        if (pages.isFirstPage && widget.onPrevious != null) {
          _goPrevious();
        } else {
          pages.previousPage();
        }
        return;
      }
      if (position.dx > width * 0.7) {
        if (pages.isLastPage && widget.onNext != null) {
          _goNext();
        } else {
          pages.nextPage();
        }
        return;
      }
    }
    setState(() => chromeVisible = !chromeVisible);
  }

  Future<void> _toggleImmersive() async {
    final next = !immersive;
    setState(() {
      immersive = next;
      chromeVisible = true;
    });
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  // Pinch zoom changes the text size itself (not a visual scale), so text
  // re-wraps to the screen, like the web reader.
  void _onPointerDown(PointerDownEvent event) {
    pointers[event.pointer] = event.position;
    if (pointers.length == 1) {
      tapDownPosition = event.position;
      tapDownTime = DateTime.now();
      // A touch that stops a fling isn't a tap on the page.
      tapCancelled =
          !paged &&
          scrollController.hasClients &&
          scrollController.position.isScrollingNotifier.value;
    } else {
      tapCancelled = true;
    }
    if (pointers.length == 2) {
      final positions = pointers.values.toList();
      pinchStartDistance = (positions[0] - positions[1]).distance;
      pinchStartFontSize = ref.read(readerAppearanceProvider).fontSize;
      setState(() {});
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!pointers.containsKey(event.pointer)) return;
    pointers[event.pointer] = event.position;
    final down = tapDownPosition;
    if (down != null && (event.position - down).distance > kTouchSlop) {
      tapCancelled = true;
    }
    final startDistance = pinchStartDistance;
    final startSize = pinchStartFontSize;
    if (pointers.length != 2 || startDistance == null || startSize == null) {
      return;
    }
    if (startDistance <= 0) return;
    final positions = pointers.values.toList();
    final scale = (positions[0] - positions[1]).distance / startDistance;
    ref
        .read(readerAppearanceProvider.notifier)
        .setFontSize(startSize * scale, allowPinchRange: true);
  }

  /// A quick, still, single-finger touch counts as a tap. Drags, pinches
  /// and long presses (text selection) don't.
  void _onPointerEnd(PointerEvent event) {
    pointers.remove(event.pointer);
    final downTime = tapDownTime;
    if (event is PointerUpEvent &&
        pointers.isEmpty &&
        !tapCancelled &&
        downTime != null &&
        DateTime.now().difference(downTime) <
            const Duration(milliseconds: 300)) {
      _onTap(event.position);
    }
    if (pointers.isEmpty) {
      tapDownPosition = null;
      tapDownTime = null;
    }
    if (pointers.length < 2 && pinchStartDistance != null) {
      setState(() {
        pinchStartDistance = null;
        pinchStartFontSize = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(readerAppearanceProvider);
    final theme = appearance.theme;
    final padding = MediaQuery.paddingOf(context);
    // Switching layouts keeps the reader's place: the page view opens at
    // the current progress (initialFraction); the scroll view jumps to it.
    if (lastPaged != null && lastPaged != appearance.paged) {
      pendingFraction = progress.value;
    }
    lastPaged = appearance.paged;

    final blocks = widget.blocks;
    var complete = false;
    if (blocks != null) {
      if (builtFor != widget.sectionKey) {
        builtFor = widget.sectionKey;
        builtCount = math.min(blocks.length, _firstChunk);
      }
      builtCount = math.min(builtCount, blocks.length);
      complete = builtCount >= blocks.length;
      if (!complete) _scheduleGrow();
    }
    _applyPending(complete);
    // Content that must be complete before it's shown — page view (to
    // measure pages) or a jump to a saved/end position — waits behind the
    // loader instead of flashing or jumping.
    final waiting =
        blocks != null &&
        !complete &&
        (appearance.paged || (pendingFraction ?? 0) > 0);
    final transition = transitionLabel;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.background,
        drawer: widget.drawer,
        body: Stack(
          children: [
            Positioned.fill(
              child: widget.error != null
                  ? SafeArea(child: ApiErrorView(error: widget.error!))
                  : blocks == null
                  ? _ReaderLoading(
                      theme: theme,
                      label: transition ?? 'Loading chapter…',
                    )
                  : _body(
                      appearance,
                      complete ? blocks : blocks.sublist(0, builtCount),
                      complete,
                      padding,
                    ),
            ),
            if (blocks != null && (waiting || transition != null))
              Positioned.fill(
                // Blocks touches while the next section gets ready.
                child: AbsorbPointer(
                  child: ColoredBox(
                    color: waiting
                        ? theme.background
                        : theme.background.withValues(alpha: 0.85),
                    child: _ReaderLoading(
                      theme: theme,
                      label: transition ?? 'Loading chapter…',
                    ),
                  ),
                ),
              ),
            // Progress hairline; stays visible with the chrome hidden, as on
            // the web.
            Positioned(
              top: padding.top,
              left: 0,
              right: 0,
              child: ValueListenableBuilder(
                valueListenable: progress,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: widget.overallProgress(value),
                  minHeight: 3,
                  color: AppTheme.primary,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            _SlidingBar(
              visible: chromeVisible,
              top: true,
              child: _TopBar(
                theme: theme,
                title: widget.title,
                subtitle: widget.subtitle,
                onBack: () => context.pop(),
                onContents: widget.drawer == null
                    ? null
                    : () => scaffoldKey.currentState?.openDrawer(),
                actions: widget.actions,
                onSettings: () => showReaderSettingsSheet(context),
                immersive: immersive,
                onToggleImmersive: _toggleImmersive,
              ),
            ),
            _SlidingBar(
              visible: chromeVisible,
              top: false,
              child: ValueListenableBuilder(
                valueListenable: progress,
                builder: (context, value, _) => _BottomBar(
                  theme: theme,
                  label: widget.bottomLabel,
                  progressLabel:
                      '${widget.sectionProgressLabel} ${(value * 100).round()}%'
                      ' · Overall ${(widget.overallProgress(value) * 100).round()}%',
                ),
              ),
            ),
            // With the bars hidden, a small overall-percentage pill keeps the
            // reader oriented.
            Positioned(
              right: 10,
              bottom: padding.bottom + 10,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: chromeVisible ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: ValueListenableBuilder(
                    valueListenable: progress,
                    builder: (context, value, _) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: readerGlassDecoration(
                        theme,
                        radius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${(widget.overallProgress(value) * 100).round()}%',
                        style: TextStyle(
                          color: theme.heading,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _body(
    ReaderAppearance appearance,
    List<Widget> blocks,
    bool complete,
    EdgeInsets padding,
  ) {
    final pinching = pinchStartDistance != null;
    return Listener(
      // A raw Listener, not a GestureDetector: SelectionArea's own tap
      // recognizer would win the gesture arena and swallow an onTap here.
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: SelectionArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: appearance.paged && !complete
              // Pages are measured from the whole section; the loader
              // covers this until every block is built.
              ? const SizedBox.expand()
              : appearance.paged
              ? PagedContentView(
                  key: pagedKey,
                  // Re-measure pages only when text layout can change.
                  layoutKey: (
                    widget.sectionKey,
                    appearance.fontSize,
                    appearance.lineHeight,
                    appearance.fontKey,
                  ),
                  // Pages sit clear of the floating bars.
                  padding: EdgeInsets.fromLTRB(
                    20,
                    padding.top + 80,
                    20,
                    padding.bottom + 84,
                  ),
                  pinching: pinching,
                  initialFraction: pendingFraction ?? progress.value,
                  onProgress: _reportProgress,
                  children: blocks,
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  // Hold the page still while two fingers resize the text.
                  // Always scrollable so even a short section can be pulled
                  // past its end to reach the next one.
                  physics: pinching
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    padding.top + 84,
                    20,
                    padding.bottom + 110,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Each block paints once and is then reused while
                          // scrolling, instead of repainting the whole
                          // section every frame.
                          for (final block in blocks)
                            RepaintBoundary(child: block),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading({required this.theme, required this.label});

  final ReaderTheme theme;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: TextStyle(
            color: theme.text.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// Reader-styled HTML: the reader's font, size, line height and theme
/// colors applied to a section's markup.
class ReaderHtml extends StatelessWidget {
  const ReaderHtml({
    super.key,
    required this.html,
    required this.appearance,
    this.extensions = const [],
    this.onLinkTap,
  });

  final String html;
  final ReaderAppearance appearance;
  final List<HtmlExtension> extensions;
  final OnTap? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final theme = appearance.theme;
    final textStyle = readerTextStyle(appearance);
    final headingStyle = Style(
      color: theme.heading,
      fontFamily: textStyle.fontFamily,
      fontFamilyFallback: textStyle.fontFamilyFallback,
    );
    return Html(
      data: html,
      extensions: extensions,
      onLinkTap: onLinkTap,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(appearance.fontSize),
          lineHeight: LineHeight(appearance.lineHeight),
          color: theme.text,
          fontFamily: textStyle.fontFamily,
          fontFamilyFallback: textStyle.fontFamilyFallback,
          // Left-aligned like the web readers: justified text reads
          // unevenly on narrow screens.
          textAlign: TextAlign.start,
        ),
        'p': Style(
          margin: Margins.only(bottom: appearance.fontSize * 0.9),
          textAlign: TextAlign.start,
        ),
        'h1': headingStyle,
        'h2': headingStyle,
        'h3': headingStyle,
        'h4': headingStyle,
        'strong': Style(color: theme.heading),
        'b': Style(color: theme.heading),
        'a': Style(color: theme.link, textDecorationColor: theme.link),
        'blockquote': Style(
          margin: Margins.symmetric(vertical: 12),
          padding: HtmlPaddings.only(left: 14),
          border: Border(left: BorderSide(color: theme.border, width: 3)),
          fontStyle: FontStyle.italic,
        ),
        'hr': Style(
          margin: Margins.symmetric(vertical: 20),
          border: Border(bottom: BorderSide(color: theme.border)),
        ),
        'img': Style(width: Width(100, Unit.percent), height: Height.auto()),
      },
    );
  }
}

TextStyle readerTextStyle(ReaderAppearance appearance) => appearance.font.apply(
  TextStyle(
    fontSize: appearance.fontSize,
    height: appearance.lineHeight,
    color: appearance.theme.text,
  ),
);

/// Closes a section and tells the reader how to carry on into the next.
class ReaderSectionEnd extends StatelessWidget {
  const ReaderSectionEnd({
    super.key,
    required this.appearance,
    required this.nextTitle,
    this.nextLabel = 'NEXT CHAPTER',
  });

  final ReaderAppearance appearance;
  final String? nextTitle;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final theme = appearance.theme;
    final paged = appearance.paged;
    final muted = theme.text.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: theme.border),
          const SizedBox(height: 16),
          if (nextTitle == null)
            Text(
              'The End',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            )
          else ...[
            Text(
              nextLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextTitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  paged
                      ? Icons.swipe_left_outlined
                      : Icons.keyboard_double_arrow_down,
                  size: 16,
                  color: muted,
                ),
                const SizedBox(width: 6),
                Text(
                  paged ? 'Swipe to continue' : 'Keep scrolling to continue',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of a reader's contents drawer.
@immutable
final class ReaderTocItem {
  const ReaderTocItem({required this.title, this.eyebrow, this.depth = 0});

  final String title;

  /// Small label above the title (e.g. "CHAPTER 3").
  final String? eyebrow;

  /// Nesting level, for sub-sections.
  final int depth;
}

class ReaderContentsDrawer extends StatefulWidget {
  const ReaderContentsDrawer({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.emptyMessage = 'No chapters available.',
  });

  final List<ReaderTocItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final String emptyMessage;

  @override
  State<ReaderContentsDrawer> createState() => _ReaderContentsDrawerState();
}

class _ReaderContentsDrawerState extends State<ReaderContentsDrawer> {
  final currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Bring the current item into view, like the web contents sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = currentKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Contents',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: widget.items.isEmpty
                ? Center(child: Text(widget.emptyMessage))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final current = index == widget.currentIndex;
                      return Padding(
                        key: current ? currentKey : null,
                        padding: EdgeInsets.only(
                          bottom: 4,
                          left: 16.0 * item.depth,
                        ),
                        child: Material(
                          color: current
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => widget.onSelected(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.eyebrow != null) ...[
                                    Text(
                                      item.eyebrow!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.6,
                                        color: current
                                            ? Colors.white70
                                            : AppTheme.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: current
                                          ? Colors.white
                                          : AppTheme.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Slides a floating bar off its edge when the reader chrome is hidden.
class _SlidingBar extends StatelessWidget {
  const _SlidingBar({
    required this.visible,
    required this.top,
    required this.child,
  });

  final bool visible;
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top ? 0 : null,
    bottom: top ? null : 0,
    child: IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : Offset(0, top ? -1.2 : 1.2),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: SafeArea(
          top: top,
          bottom: !top,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onContents,
    required this.actions,
    required this.onSettings,
    required this.immersive,
    required this.onToggleImmersive,
  });

  final ReaderTheme theme;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onContents;
  final List<ReaderBarAction> actions;
  final VoidCallback onSettings;
  final bool immersive;
  final VoidCallback onToggleImmersive;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    decoration: readerGlassDecoration(
      theme,
      radius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Row(
      children: [
        _BarButton(
          theme: theme,
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.text.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        if (onContents != null)
          _BarButton(
            theme: theme,
            icon: Icons.format_list_bulleted,
            tooltip: 'Contents',
            onPressed: onContents,
          ),
        for (final action in actions)
          _BarButton(
            theme: theme,
            icon: action.icon,
            tooltip: action.tooltip,
            onPressed: action.onPressed,
          ),
        _BarButton(
          theme: theme,
          icon: Icons.tune,
          tooltip: 'Reader settings',
          onPressed: onSettings,
        ),
        _BarButton(
          theme: theme,
          icon: immersive ? Icons.fullscreen_exit : Icons.fullscreen,
          tooltip: immersive ? 'Exit fullscreen' : 'Fullscreen',
          onPressed: onToggleImmersive,
        ),
      ],
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.theme,
    required this.label,
    required this.progressLabel,
  });

  final ReaderTheme theme;
  final String label;
  final String progressLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: readerGlassDecoration(
      theme,
      radius: BorderRadius.circular(AppTheme.radius),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.heading,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                progressLabel,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.text.withValues(alpha: 0.75),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.theme,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final ReaderTheme theme;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, size: 22),
    color: theme.heading,
    disabledColor: theme.text.withValues(alpha: 0.3),
    visualDensity: VisualDensity.compact,
  );
}
