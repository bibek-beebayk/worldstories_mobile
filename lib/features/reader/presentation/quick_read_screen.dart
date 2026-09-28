import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../story/presentation/story_detail_screen.dart';
import '../../story/presentation/story_title.dart';
import '../data/quick_read_progress_repository.dart';
import '../../../core/api_error_view.dart';

class QuickReadScreen extends ConsumerStatefulWidget {
  const QuickReadScreen({super.key, required this.storySlug});
  final String storySlug;
  @override
  ConsumerState<QuickReadScreen> createState() => _QuickReadScreenState();
}

class _QuickReadScreenState extends ConsumerState<QuickReadScreen> {
  final scrollController = ScrollController();
  Timer? saveTimer;
  bool restored = false;
  bool openedTracked = false;

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
    SimpleProgress? saved;
    try {
      saved = await ref
          .read(quickReadProgressRepositoryProvider)
          .fetch(widget.storySlug);
    } catch (_) {
      return;
    }
    if (saved == null) return;
    final progress = saved.progress;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) {
        scrollController.jumpTo(
          scrollController.position.maxScrollExtent * progress,
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
      await ref
          .read(quickReadProgressRepositoryProvider)
          .save(storySlug: widget.storySlug, progress: progress);
    } catch (_) {
      // Progress is best-effort during reading; the next scroll retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final storyTitle = watchStoryTitle(ref, widget.storySlug);
    return Scaffold(
      appBar: AppBar(title: Text(storyTitle, overflow: TextOverflow.ellipsis)),
      body: ref
          .watch(storyDetailProvider(widget.storySlug))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ApiErrorView(error: error),
            data: (story) {
              if (story.summary.isEmpty) {
                return const Center(child: Text('No quick read available.'));
              }
              _restore();
              if (!openedTracked) {
                openedTracked = true;
                ref
                    .read(analyticsServiceProvider)
                    .track(
                      AnalyticsEventType.quickReadOpened,
                      storySlug: story.slug,
                    );
              }
              return SelectionArea(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Divider(height: 32),
                      Html(
                        data: story.summary,
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
                      const SizedBox(height: 32),
                      OutlinedButton(
                        onPressed: () {
                          ref
                              .read(analyticsServiceProvider)
                              .track(
                                AnalyticsEventType.quickReadFullStoryClicked,
                                storySlug: story.slug,
                              );
                          context.pushReplacement('/story/${story.slug}');
                        },
                        child: const Text('Read the full story'),
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
