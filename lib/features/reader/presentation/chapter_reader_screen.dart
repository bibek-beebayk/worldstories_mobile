import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/presentation/story_title.dart';
import '../data/chapter_repository.dart';
import '../data/reading_progress_repository.dart';
import '../../../core/api_error_view.dart';

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

class ChapterReaderScreen extends ConsumerStatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.storySlug,
    required this.chapterSlug,
  });
  final String storySlug;
  final String chapterSlug;
  @override
  ConsumerState<ChapterReaderScreen> createState() =>
      _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends ConsumerState<ChapterReaderScreen> {
  final scrollController = ScrollController();
  Timer? saveTimer;
  bool restored = false;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_scheduleSave);
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (restored || !signedIn) return;
    restored = true;
    ReadingProgress? saved;
    try {
      saved = await ref
          .read(readingProgressRepositoryProvider)
          .fetch(widget.storySlug);
    } catch (_) {
      return;
    }
    if (saved == null || saved.chapterSlug != widget.chapterSlug) return;
    final savedProgress = saved.progress;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) {
        scrollController.jumpTo(
          scrollController.position.maxScrollExtent * savedProgress,
        );
      }
    });
  }

  void _scheduleSave() {
    if (!signedIn || !scrollController.hasClients) return;
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 900), _saveProgress);
  }

  Future<void> _saveProgress() async {
    if (!mounted || !scrollController.hasClients) return;
    final max = scrollController.position.maxScrollExtent;
    final progress = max <= 0
        ? 1.0
        : (scrollController.offset / max).clamp(0.0, 1.0);
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

  @override
  Widget build(BuildContext context) {
    final key = (story: widget.storySlug, chapter: widget.chapterSlug);
    final storyTitle = watchStoryTitle(ref, widget.storySlug);
    return Scaffold(
      appBar: AppBar(title: Text(storyTitle, overflow: TextOverflow.ellipsis)),
      body: ref
          .watch(chapterProvider(key))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ApiErrorView(error: error),
            data: (chapter) {
              _restore();
              return SelectionArea(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Divider(height: 32),
                      Html(
                        data: chapter.html,
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(18),
                            lineHeight: const LineHeight(1.65),
                          ),
                          'p': Style(margin: Margins.only(bottom: 16)),
                          'img': Style(
                            width: Width(100, Unit.percent),
                            height: Height.auto(),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
