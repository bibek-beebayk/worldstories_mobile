import 'dart:async';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../../../core/providers.dart';
import '../../../shared/widgets/cached_app_image.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/presentation/story_title.dart';
import '../application/epub_progress.dart';
import '../data/epub_document_repository.dart';
import '../data/file_reading_progress_repository.dart';

final epubDocumentRepositoryProvider = Provider<EpubDocumentRepository>(
  (ref) => EpubDocumentRepository(ref.watch(apiClientProvider)),
);

class EpubReaderScreen extends ConsumerStatefulWidget {
  const EpubReaderScreen({super.key, required this.storySlug});
  final String storySlug;
  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  EpubController? controller;
  Timer? saveTimer;
  bool initStarted = false;
  bool userHasScrolled = false;
  int totalParagraphs = 0;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Guards against being kicked off more than once: without this, a widget
    // rebuild before the first fetch resolves would start a second, competing
    // download of the same (potentially large) EPUB file, and neither one may
    // ever win — this was the cause of the reader appearing stuck on loading.
    if (initStarted) return;
    initStarted = true;
    String? initialCfi;
    if (signedIn) {
      try {
        final saved = await ref
            .read(fileReadingProgressRepositoryProvider)
            .fetch(widget.storySlug, FileReadingFormat.epub);
        initialCfi = saved?.position;
      } catch (_) {
        // Best-effort restore; fall back to the start of the book.
      }
    }
    // `await`ing here (even when there's nothing to await above, i.e. the
    // anonymous-user path) pushes `setState` past the current build/init
    // call stack — calling it synchronously inside `initState` is illegal.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() {
      controller = EpubController(
        document: ref
            .read(epubDocumentRepositoryProvider)
            .fetch(widget.storySlug),
        epubCfi: initialCfi,
      );
    });
  }

  // `EpubChapterViewValue` (the parameter type `EpubView.onChapterChanged`
  // declares) isn't exported by the package's public barrel, only used
  // internally — so callers can't name the type without reaching into
  // `package:epub_view/src/...`. Accepting `dynamic` here avoids that
  // fragile internal import; `chapterNumber` is still a real field on the
  // object at runtime.
  void _onChapterChanged(dynamic value) {
    if (!signedIn || value == null || controller == null) return;
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(milliseconds: 900),
      () => _saveProgress(value),
    );
  }

  Future<void> _saveProgress(dynamic value) async {
    if (!mounted || controller == null) return;
    final totalChapters = controller!.tableOfContents().length;
    final chapterNumber = value.chapterNumber as int;
    final position = value.position;
    final paragraphIndex = position.index as int;
    final hasParagraphCount = totalParagraphs > 0;
    final currentIndex = hasParagraphCount
        ? paragraphIndex
        : (chapterNumber - 1).clamp(0, totalChapters);
    final totalItems = hasParagraphCount ? totalParagraphs : totalChapters;
    final trailingEdge = position.itemTrailingEdge as double;
    final reachedEnd =
        hasParagraphCount &&
        userHasScrolled &&
        paragraphIndex >= totalParagraphs - 1 &&
        trailingEdge > 0 &&
        trailingEdge <= 1.01;
    final progress = calculateEpubProgress(
      currentIndex: currentIndex,
      totalItems: totalItems,
      reachedEnd: reachedEnd,
    );
    final cfi = controller!.generateEpubCfi();
    try {
      final result = await ref
          .read(fileReadingProgressRepositoryProvider)
          .save(
            storySlug: widget.storySlug,
            format: FileReadingFormat.epub,
            progress: progress,
            position: cfi,
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
      // Progress is best-effort during reading; the next chapter turn retries.
    }
  }

  void _documentLoaded(EpubBook document) {
    totalParagraphs = _countParagraphs(document);
  }

  bool _observeReaderScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      userHasScrolled = true;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      userHasScrolled = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final storyTitle = watchStoryTitle(ref, widget.storySlug);
    if (controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(storyTitle, overflow: TextOverflow.ellipsis),
        ),
        body: const BookPageOpeningLoader(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(storyTitle, overflow: TextOverflow.ellipsis)),
      body: NotificationListener<ScrollNotification>(
        onNotification: _observeReaderScroll,
        child: EpubView(
          controller: controller!,
          onChapterChanged: _onChapterChanged,
          onDocumentLoaded: _documentLoaded,
          builders: const EpubViewBuilders<DefaultBuilderOptions>(
            options: DefaultBuilderOptions(),
            loaderBuilder: _epubLoader,
          ),
          onDocumentError: (error) =>
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error?.toString() ?? 'Failed to load EPUB'),
                ),
              ),
        ),
      ),
    );
  }
}

Widget _epubLoader(BuildContext context) => const BookPageOpeningLoader();

int _countParagraphs(EpubBook document) {
  final chapters = <EpubChapter>[];
  for (final chapter in document.Chapters ?? const <EpubChapter>[]) {
    chapters.add(chapter);
    chapters.addAll(chapter.SubChapters ?? const <EpubChapter>[]);
  }

  String? previousFile;
  var count = 0;
  for (final chapter in chapters) {
    if (chapter.ContentFileName == previousFile) continue;
    previousFile = chapter.ContentFileName;
    final markup = chapter.HtmlContent;
    if (markup == null || markup.isEmpty) continue;
    final body = html_parser.parse(markup).body;
    if (body != null) count += _flattenedElements(body.children).length;
  }
  return count;
}

List<html_dom.Element> _flattenedElements(List<html_dom.Element> elements) {
  final flattened = <html_dom.Element>[];
  for (final element in elements) {
    if (element.localName == 'div' && element.children.length > 1) {
      flattened.addAll(_flattenedElements(element.children));
    } else {
      flattened.add(element);
    }
  }
  return flattened;
}
