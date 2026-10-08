import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format_icons.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/presentation/story_detail_screen.dart';
import '../application/reader_appearance.dart';
import '../data/chapter_repository.dart';
import '../data/reading_progress_repository.dart';
import 'reader_shell.dart';

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

/// The HTML chapter reader, modelled on the web reader (StoryReader.tsx).
/// The reading experience itself is [ReaderShell]; this screen loads the
/// chapter, restores and saves reading progress, and moves between
/// chapters (each chapter is its own route).
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
  final shell = ReaderShellController();
  Timer? saveTimer;
  bool restored = false;

  /// Saves wait until the saved position has been restored, so opening a
  /// chapter can't overwrite the reader's real progress with 0.
  bool restoreDone = false;

  /// The next chapter, fetched in the background once the reader is well
  /// into this one so the hand-off is instant.
  String? nextChapterSlug;
  bool prefetched = false;
  static const _prefetchAt = 0.6;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void dispose() {
    saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    if (restored) return;
    restored = true;
    try {
      if (!widget.startAtEnd && signedIn) {
        final saved = await ref
            .read(readingProgressRepositoryProvider)
            .fetch(widget.storySlug);
        if (mounted && saved?.chapterSlug == widget.chapterSlug) {
          shell.jumpToFraction(saved!.progress);
        }
      }
    } catch (_) {
      // Best-effort restore; stay at the start.
    } finally {
      restoreDone = true;
      // Record the starting position even if the reader never scrolls (a
      // short chapter), so "continue reading" still advances.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onProgress(shell.fraction);
      });
    }
  }

  void _onProgress(double value) {
    _maybePrefetch(value);
    if (!signedIn || !restoreDone) return;
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(milliseconds: 900),
      () => _saveProgress(value),
    );
  }

  void _maybePrefetch(double value) {
    final next = nextChapterSlug;
    if (prefetched || next == null || value < _prefetchAt) return;
    prefetched = true;
    // Reading the (kept-alive) provider starts the fetch and caches the
    // result for the next chapter's screen; failures just retry there.
    ref
        .read(chapterProvider((story: widget.storySlug, chapter: next)).future)
        .ignore();
  }

  Future<void> _saveProgress(double progress) async {
    if (!mounted) return;
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

  void _openChapter(String chapterSlug, {bool atEnd = false}) {
    if (chapterSlug == widget.chapterSlug) return;
    context.pushReplacement(
      '/read/${widget.storySlug}/$chapterSlug${atEnd ? '?at=end' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(readerAppearanceProvider);
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
    nextChapterSlug = next?.slug;
    if (chapter != null) _restore();

    return ReaderShell(
      controller: shell,
      sectionKey: widget.chapterSlug,
      initialFraction: widget.startAtEnd ? 1 : 0,
      title: story?.title ?? chapter?.title ?? '',
      subtitle: chapter?.title ?? '',
      bottomLabel: chapter == null
          ? ''
          : 'Chapter ${index >= 0 ? index + 1 : chapter.order}'
                '${chapters.isEmpty ? '' : ' / ${chapters.length}'}'
                ': ${chapter.title}',
      // Each chapter is an equal slice of the story, as on the web (real
      // chapter lengths aren't known up front).
      overallProgress: (fraction) => chapters.isEmpty || index < 0
          ? fraction
          : ((index + fraction) / chapters.length).clamp(0.0, 1.0),
      error: chapterAsync.error,
      blocks: chapter == null
          ? null
          : _chapterBlocks(chapter, appearance, next?.title),
      onProgress: _onProgress,
      onNext: next == null ? null : () => _openChapter(next.slug),
      onPrevious: previous == null
          ? null
          : () => _openChapter(previous.slug, atEnd: true),
      actions: [
        if (story?.summary.isNotEmpty ?? false)
          ReaderBarAction(
            icon: FormatIcons.quickRead,
            tooltip: 'Switch to Quick Read',
            onPressed: () => context.push('/quick-read/${widget.storySlug}'),
          ),
      ],
      drawer: ReaderContentsDrawer(
        items: [
          for (final item in chapters)
            ReaderTocItem(title: item.title, eyebrow: 'CHAPTER ${item.order}'),
        ],
        currentIndex: index,
        onSelected: (selected) {
          Navigator.pop(context);
          _openChapter(chapters[selected].slug);
        },
      ),
    );
  }
}

List<Widget> _chapterBlocks(
  ChapterContent chapter,
  ReaderAppearance appearance,
  String? nextChapterTitle,
) {
  final theme = appearance.theme;
  return [
    Text(
      'Chapter ${chapter.order}',
      style: TextStyle(
        color: theme.text.withValues(alpha: 0.7),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
    // Most chapters' HTML opens with its own title heading; only add one
    // when it doesn't, so the title appears once.
    if (!chapter.htmlStartsWithTitle)
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            chapter.title,
            style: readerTextStyle(appearance).copyWith(
              color: theme.heading,
              fontSize: appearance.fontSize * 1.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          Divider(height: 36, color: theme.border),
        ],
      )
    else
      const SizedBox(height: 8),
    for (final block in chapter.blocks)
      ReaderHtml(html: block, appearance: appearance),
    ReaderSectionEnd(appearance: appearance, nextTitle: nextChapterTitle),
  ];
}
