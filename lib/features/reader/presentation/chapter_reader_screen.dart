import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/format_icons.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/data/story_detail_repository.dart';
import '../../story/presentation/story_detail_screen.dart';
import '../application/reader_appearance.dart';
import '../data/chapter_repository.dart';
import '../data/reading_progress_repository.dart';
import '../../../core/api_error_view.dart';
import 'paged_content_view.dart';
import 'reader_settings_sheet.dart';

final chapterRepositoryProvider = Provider<ChapterRepository>(
  (ref) => ChapterRepository(ref.watch(apiClientProvider)),
);
final chapterProvider =
    FutureProvider.family<ChapterContent, ({String story, String chapter})>(
      (ref, key) => ref
          .watch(chapterRepositoryProvider)
          .fetch(storySlug: key.story, chapterSlug: key.chapter),
    );
final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>(
  (ref) => ReadingProgressRepository(ref.watch(apiClientProvider)),
);

/// The HTML chapter reader, modelled on the web reader (StoryReader.tsx):
/// a themed, full-screen reading surface whose floating top and bottom bars
/// toggle on tap, with a contents drawer, reader settings (size, line
/// height, theme, custom themes, font), pinch-to-zoom text, chapter
/// navigation and story/chapter progress.
class ChapterReaderScreen extends ConsumerStatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.storySlug,
    required this.chapterSlug,
    this.startAtEnd = false,
  });
  final String storySlug;
  final String chapterSlug;

  /// Open at the chapter's end (arriving backwards from the next chapter).
  final bool startAtEnd;
  @override
  ConsumerState<ChapterReaderScreen> createState() =>
      _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends ConsumerState<ChapterReaderScreen> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final scrollController = ScrollController();

  /// How far through this chapter the reader is (0–1). A notifier rather
  /// than state so scrolling only rebuilds the progress UI, not the HTML.
  final chapterProgress = ValueNotifier<double>(0);
  final pagedKey = GlobalKey<PagedContentViewState>();
  Timer? saveTimer;
  bool restored = false;

  /// Saves wait until the saved position has been restored, so opening a
  /// chapter can't overwrite the reader's real progress with 0.
  bool restoreDone = false;
  bool? lastPaged;
  String? nextChapterSlug;
  String? previousChapterSlug;

  /// How far the reader has pulled past either end of the chapter
  /// (negative = before the start). Past [_pullThreshold] the neighbouring
  /// chapter opens.
  double pull = 0;
  bool leavingChapter = false;
  static const _pullThreshold = 72.0;
  bool chromeVisible = true;
  bool immersive = false;

  // Pinch-to-zoom: the live pointers and the size/distance the pinch
  // started from.
  final pointers = <int, Offset>{};
  double? pinchStartDistance;
  double? pinchStartFontSize;

  // Tap-to-toggle tracking (see _onPointerEnd).
  Offset? tapDownPosition;
  DateTime? tapDownTime;
  bool tapCancelled = false;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    scrollController.dispose();
    chapterProgress.dispose();
    if (immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _restore() async {
    if (restored) return;
    restored = true;
    try {
      await _jumpToSavedPosition();
    } finally {
      restoreDone = true;
      // Record the starting position even if the reader never scrolls (a
      // short chapter), so "continue reading" still advances.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(readerAppearanceProvider).paged) {
          _reportProgress(chapterProgress.value);
        } else {
          _onScroll();
        }
      });
    }
  }

  Future<void> _jumpToSavedPosition() async {
    if (widget.startAtEnd) {
      // Called from the first data build: wait for layout so the scroll
      // extent is known.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) _jumpToFraction(1);
      return;
    }
    if (!signedIn) return;
    ReadingProgress? saved;
    try {
      saved = await ref
          .read(readingProgressRepositoryProvider)
          .fetch(widget.storySlug);
    } catch (_) {
      return;
    }
    if (!mounted || saved == null || saved.chapterSlug != widget.chapterSlug) {
      return;
    }
    _jumpToFraction(saved.progress);
  }

  void _jumpToFraction(double fraction) {
    if (ref.read(readerAppearanceProvider).paged) {
      chapterProgress.value = fraction;
      pagedKey.currentState?.jumpToFraction(fraction);
    } else if (scrollController.hasClients) {
      scrollController.jumpTo(
        scrollController.position.maxScrollExtent * fraction,
      );
    }
  }

  /// Continuous reading: dragging on past the end of a chapter (scrolling
  /// down, or swiping on from the last page) opens the next chapter, and
  /// past the start opens the previous one at its end.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || leavingChapter) return false;
    final paged = ref.read(readerAppearanceProvider).paged;
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
    final next = nextChapterSlug;
    final previous = previousChapterSlug;
    if (pull > _pullThreshold && next != null) {
      leavingChapter = true;
      _openChapter(next);
    } else if (pull < -_pullThreshold && previous != null) {
      leavingChapter = true;
      _openChapter(previous, atEnd: true);
    }
    return false;
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final max = scrollController.position.maxScrollExtent;
    _reportProgress(
      max <= 0 ? 1 : (scrollController.offset / max).clamp(0.0, 1.0),
    );
  }

  /// Progress from either layout: updates the bars and schedules a save.
  void _reportProgress(double value) {
    chapterProgress.value = value;
    if (!signedIn || !restoreDone) return;
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 900), _saveProgress);
  }

  Future<void> _saveProgress() async {
    if (!mounted) return;
    final progress = chapterProgress.value;
    try {
      final result = await ref
          .read(readingProgressRepositoryProvider)
          .save(
            storySlug: widget.storySlug,
            chapterSlug: widget.chapterSlug,
            progress: progress,
          );
      if (!mounted) return;
      handleCompletionSignals(
        context,
        ref,
        widget.storySlug,
        storyCompleted: result.storyCompleted,
        unlockedCountry: result.unlockedCountry,
        unlockedAchievements: result.unlockedAchievements,
      );
    } catch (_) {
      // Progress is best-effort during reading; the next scroll retries.
    }
  }

  /// In page view the outer thirds of the screen turn pages (the right edge
  /// of a chapter's last page opens the next chapter); elsewhere a tap
  /// shows or hides the reader bars.
  void _onTap(Offset position) {
    final pages = pagedKey.currentState;
    if (ref.read(readerAppearanceProvider).paged && pages != null) {
      final width = MediaQuery.sizeOf(context).width;
      if (position.dx < width * 0.3) {
        final previous = previousChapterSlug;
        if (pages.isFirstPage && previous != null) {
          _openChapter(previous, atEnd: true);
        } else {
          pages.previousPage();
        }
        return;
      }
      if (position.dx > width * 0.7) {
        final next = nextChapterSlug;
        if (pages.isLastPage && next != null) {
          _openChapter(next);
        } else {
          pages.nextPage();
        }
        return;
      }
    }
    _toggleChrome();
  }

  void _toggleChrome() => setState(() => chromeVisible = !chromeVisible);

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

  void _openChapter(String chapterSlug, {bool atEnd = false}) {
    if (chapterSlug == widget.chapterSlug) return;
    context.pushReplacement(
      '/read/${widget.storySlug}/$chapterSlug${atEnd ? '?at=end' : ''}',
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
          !ref.read(readerAppearanceProvider).paged &&
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

  /// A quick, still, single-finger touch toggles the reader chrome. Drags,
  /// pinches and long presses (text selection) don't.
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
    final story = ref.watch(storyDetailProvider(widget.storySlug)).value;
    final chapterAsync = ref.watch(
      chapterProvider((story: widget.storySlug, chapter: widget.chapterSlug)),
    );
    final chapters = [...?story?.chapters]
      ..sort((a, b) => a.order.compareTo(b.order));
    final index = chapters.indexWhere(
      (item) => item.slug == widget.chapterSlug,
    );
    final previous = index > 0 ? chapters[index - 1] : null;
    final next = index >= 0 && index < chapters.length - 1
        ? chapters[index + 1]
        : null;
    final chapter = chapterAsync.value;
    final padding = MediaQuery.paddingOf(context);
    nextChapterSlug = next?.slug;
    previousChapterSlug = previous?.slug;
    // Switching layouts keeps the reader's place: the page view opens at
    // the current progress (initialFraction); the scroll view jumps to it.
    if (lastPaged == true && !appearance.paged) {
      final fraction = chapterProgress.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scrollController.hasClients) {
          scrollController.jumpTo(
            scrollController.position.maxScrollExtent * fraction,
          );
        }
      });
    }
    lastPaged = appearance.paged;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.background,
        drawer: _ContentsDrawer(
          chapters: chapters,
          currentSlug: widget.chapterSlug,
          onSelected: (slug) {
            Navigator.pop(context);
            _openChapter(slug);
          },
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: chapterAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: theme.link)),
                error: (error, _) =>
                    SafeArea(child: ApiErrorView(error: error)),
                data: (chapter) {
                  _restore();
                  return _ChapterBody(
                    chapter: chapter,
                    appearance: appearance,
                    scrollController: scrollController,
                    pagedKey: pagedKey,
                    pinching: pinchStartDistance != null,
                    scrollPadding: EdgeInsets.fromLTRB(
                      20,
                      padding.top + 84,
                      20,
                      padding.bottom + 110,
                    ),
                    // Pages sit clear of the floating bars.
                    pagePadding: EdgeInsets.fromLTRB(
                      20,
                      padding.top + 80,
                      20,
                      padding.bottom + 84,
                    ),
                    initialFraction: chapterProgress.value,
                    onPageProgress: _reportProgress,
                    onScrollNotification: _onScrollNotification,
                    nextChapterTitle: next?.title,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerEnd: _onPointerEnd,
                  );
                },
              ),
            ),
            // Story progress hairline; stays visible with the chrome hidden,
            // as on the web.
            Positioned(
              top: padding.top,
              left: 0,
              right: 0,
              child: ValueListenableBuilder(
                valueListenable: chapterProgress,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: _overall(index, chapters.length, value),
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
                storyTitle: story?.title ?? chapter?.title ?? '',
                chapterTitle: chapter?.title ?? '',
                showQuickRead: story?.summary.isNotEmpty ?? false,
                onBack: () => context.pop(),
                onContents: () => scaffoldKey.currentState?.openDrawer(),
                onQuickRead: () =>
                    context.push('/quick-read/${widget.storySlug}'),
                onSettings: () => showReaderSettingsSheet(context),
                immersive: immersive,
                onToggleImmersive: _toggleImmersive,
              ),
            ),
            _SlidingBar(
              visible: chromeVisible,
              top: false,
              child: ValueListenableBuilder(
                valueListenable: chapterProgress,
                builder: (context, value, _) => _BottomBar(
                  theme: theme,
                  label: chapter == null
                      ? ''
                      : 'Chapter ${index >= 0 ? index + 1 : chapter.order}'
                            '${chapters.isEmpty ? '' : ' / ${chapters.length}'}'
                            ': ${chapter.title}',
                  progressLabel:
                      'Chapter ${(value * 100).round()}% · Overall '
                      '${(_overall(index, chapters.length, value) * 100).round()}%',
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
                    valueListenable: chapterProgress,
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
                        '${(_overall(index, chapters.length, value) * 100).round()}%',
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

  /// Overall story progress: each chapter is treated as an equal slice of
  /// the story, as on the web (real chapter lengths aren't known up front).
  static double _overall(int index, int total, double chapter) {
    if (total <= 0 || index < 0) return chapter;
    return ((index + chapter) / total).clamp(0.0, 1.0);
  }
}

class _ChapterBody extends StatelessWidget {
  const _ChapterBody({
    required this.chapter,
    required this.appearance,
    required this.scrollController,
    required this.pagedKey,
    required this.pinching,
    required this.scrollPadding,
    required this.pagePadding,
    required this.initialFraction,
    required this.onPageProgress,
    required this.onScrollNotification,
    required this.nextChapterTitle,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final ChapterContent chapter;
  final ReaderAppearance appearance;
  final ScrollController scrollController;
  final GlobalKey<PagedContentViewState> pagedKey;
  final bool pinching;
  final EdgeInsets scrollPadding;
  final EdgeInsets pagePadding;

  /// Where a newly shown page view opens (current progress).
  final double initialFraction;
  final ValueChanged<double> onPageProgress;
  final NotificationListenerCallback<ScrollNotification> onScrollNotification;
  final String? nextChapterTitle;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final void Function(PointerEvent) onPointerEnd;

  @override
  Widget build(BuildContext context) {
    final content = _ChapterContent(
      chapter: chapter,
      appearance: appearance,
      nextChapterTitle: nextChapterTitle,
    );
    return Listener(
      // A raw Listener, not a GestureDetector: SelectionArea's own tap
      // recognizer would win the gesture arena and swallow an onTap here.
      behavior: HitTestBehavior.opaque,
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerEnd,
      onPointerCancel: onPointerEnd,
      child: SelectionArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: onScrollNotification,
          child: appearance.paged
              ? PagedContentView(
                  key: pagedKey,
                  padding: pagePadding,
                  pinching: pinching,
                  initialFraction: initialFraction,
                  onProgress: onPageProgress,
                  child: content,
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  // Hold the page still while two fingers resize the text.
                  // Always scrollable so even a short chapter can be pulled
                  // past its end to reach the next one.
                  physics: pinching
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  padding: scrollPadding,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: content,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ChapterContent extends StatelessWidget {
  const _ChapterContent({
    required this.chapter,
    required this.appearance,
    required this.nextChapterTitle,
  });

  final ChapterContent chapter;
  final ReaderAppearance appearance;
  final String? nextChapterTitle;

  @override
  Widget build(BuildContext context) {
    final theme = appearance.theme;
    final textStyle = appearance.font.apply(
      TextStyle(
        fontSize: appearance.fontSize,
        height: appearance.lineHeight,
        color: theme.text,
      ),
    );
    final headingStyle = Style(
      color: theme.heading,
      fontFamily: textStyle.fontFamily,
      fontFamilyFallback: textStyle.fontFamilyFallback,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chapter ${chapter.order}',
          style: TextStyle(
            color: theme.text.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        // Most chapters' HTML opens with its own title heading; only add
        // one when it doesn't, so the title appears once.
        if (!chapter.htmlStartsWithTitle) ...[
          const SizedBox(height: 6),
          Text(
            chapter.title,
            style: textStyle.copyWith(
              color: theme.heading,
              fontSize: appearance.fontSize * 1.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          Divider(height: 36, color: theme.border),
        ] else
          const SizedBox(height: 8),
        Html(
          data: chapter.html,
          style: {
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontSize: FontSize(appearance.fontSize),
              lineHeight: LineHeight(appearance.lineHeight),
              color: theme.text,
              fontFamily: textStyle.fontFamily,
              fontFamilyFallback: textStyle.fontFamilyFallback,
            ),
            'p': Style(margin: Margins.only(bottom: appearance.fontSize * 0.9)),
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
            'img': Style(
              width: Width(100, Unit.percent),
              height: Height.auto(),
            ),
          },
        ),
        _ChapterEnd(
          theme: theme,
          paged: appearance.paged,
          nextChapterTitle: nextChapterTitle,
        ),
      ],
    );
  }
}

/// Closes a chapter and tells the reader how to carry on into the next.
class _ChapterEnd extends StatelessWidget {
  const _ChapterEnd({
    required this.theme,
    required this.paged,
    required this.nextChapterTitle,
  });

  final ReaderTheme theme;
  final bool paged;
  final String? nextChapterTitle;

  @override
  Widget build(BuildContext context) {
    final muted = theme.text.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: theme.border),
          const SizedBox(height: 16),
          if (nextChapterTitle == null)
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
              'NEXT CHAPTER',
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
              nextChapterTitle!,
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
    required this.storyTitle,
    required this.chapterTitle,
    required this.showQuickRead,
    required this.onBack,
    required this.onContents,
    required this.onQuickRead,
    required this.onSettings,
    required this.immersive,
    required this.onToggleImmersive,
  });

  final ReaderTheme theme;
  final String storyTitle;
  final String chapterTitle;
  final bool showQuickRead;
  final VoidCallback onBack;
  final VoidCallback onContents;
  final VoidCallback onQuickRead;
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
                storyTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                chapterTitle,
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
        _BarButton(
          theme: theme,
          icon: Icons.format_list_bulleted,
          tooltip: 'Contents',
          onPressed: onContents,
        ),
        if (showQuickRead)
          _BarButton(
            theme: theme,
            icon: FormatIcons.quickRead,
            tooltip: 'Switch to Quick Read',
            onPressed: onQuickRead,
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

class _ContentsDrawer extends StatefulWidget {
  const _ContentsDrawer({
    required this.chapters,
    required this.currentSlug,
    required this.onSelected,
  });

  final List<StoryChapter> chapters;
  final String currentSlug;
  final ValueChanged<String> onSelected;

  @override
  State<_ContentsDrawer> createState() => _ContentsDrawerState();
}

class _ContentsDrawerState extends State<_ContentsDrawer> {
  final currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Bring the current chapter into view, like the web contents sheet.
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
            child: widget.chapters.isEmpty
                ? const Center(child: Text('No chapters available.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: widget.chapters.length,
                    itemBuilder: (context, index) {
                      final item = widget.chapters[index];
                      final current = item.slug == widget.currentSlug;
                      return Padding(
                        key: current ? currentKey : null,
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: current
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => widget.onSelected(item.slug),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CHAPTER ${item.order}',
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
