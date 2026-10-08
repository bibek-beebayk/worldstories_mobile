import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/presentation/story_title.dart';
import '../application/reader_appearance.dart';
import '../data/epub_book.dart';
import '../data/epub_document_repository.dart';
import '../data/file_reading_progress_repository.dart';
import 'reader_shell.dart';

final epubDocumentRepositoryProvider = Provider<EpubDocumentRepository>(
  (ref) => EpubDocumentRepository(ref.watch(apiClientProvider)),
);

final epubBookProvider = FutureProvider.autoDispose
    .family<EpubBookData, String>(
      (ref, storySlug) =>
          ref.watch(epubDocumentRepositoryProvider).fetch(storySlug),
    );

/// The EPUB reader. It renders the book's own chapters (spine files) in the
/// same reading experience as the HTML chapter reader ([ReaderShell]):
/// themes, fonts, text size, scroll or page layout, a contents drawer from
/// the book's table of contents, and continuous reading from one chapter
/// into the next. Positions are saved as EPUB CFIs the web reader shares.
class EpubReaderScreen extends ConsumerStatefulWidget {
  const EpubReaderScreen({super.key, required this.storySlug});
  final String storySlug;
  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  final shell = ReaderShellController();
  int sectionIndex = 0;

  /// Where the current section opened: 0 = its start, 1 = its end
  /// (arrived backwards), or a restored position.
  double sectionStart = 0;
  Timer? saveTimer;
  bool restored = false;

  /// Saves wait until the saved position has been restored, so opening the
  /// book can't overwrite the reader's real progress.
  bool restoreDone = false;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void dispose() {
    saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _restore(EpubBookData book) async {
    if (restored) return;
    restored = true;
    try {
      if (signedIn) {
        final saved = await ref
            .read(fileReadingProgressRepositoryProvider)
            .fetch(widget.storySlug, FileReadingFormat.epub);
        if (!mounted || saved == null) return;
        // The CFI says which chapter; within it, the saved percentage is
        // usually finer-grained (a CFI only resolves to a paragraph block),
        // so prefer it whenever both agree on the chapter.
        final fromCfi = book.positionForCfi(saved.position);
        final fromPercent = saved.progress > 0
            ? book.positionForOverall(saved.progress)
            : null;
        final position =
            fromCfi != null &&
                fromPercent != null &&
                fromPercent.section == fromCfi.section
            ? fromPercent
            : fromCfi ?? fromPercent;
        if (position != null) {
          if (position.section == sectionIndex) {
            shell.jumpToFraction(position.fraction);
          } else {
            _openSection(position.section, start: position.fraction);
          }
        }
      }
    } catch (_) {
      // Best-effort restore; stay at the start of the book.
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        restoreDone = true;
        if (mounted) _onProgress(book, shell.fraction);
      });
    }
  }

  void _openSection(int index, {double start = 0}) {
    setState(() {
      sectionIndex = index;
      sectionStart = start;
    });
  }

  void _onProgress(EpubBookData book, double fraction) {
    if (!signedIn || !restoreDone) return;
    final section = sectionIndex;
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(milliseconds: 900),
      () => _saveProgress(book, section, fraction),
    );
  }

  Future<void> _saveProgress(
    EpubBookData book,
    int section,
    double fraction,
  ) async {
    if (!mounted) return;
    final overall = book.overallProgress(section, fraction);
    // Only the very end of the last chapter counts as finished.
    final atEnd = section == book.sections.length - 1 && fraction >= 0.995;
    try {
      final result = await ref
          .read(fileReadingProgressRepositoryProvider)
          .save(
            storySlug: widget.storySlug,
            format: FileReadingFormat.epub,
            progress: atEnd ? 1 : overall.clamp(0.0, 0.99),
            position: book.cfiFor(section, fraction),
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
      // Progress is best-effort during reading; the next page turn retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(readerAppearanceProvider);
    final storyTitle = watchStoryTitle(ref, widget.storySlug);
    final bookAsync = ref.watch(epubBookProvider(widget.storySlug));
    final book = bookAsync.value;
    if (book != null) _restore(book);

    final sections = book?.sections ?? const <EpubSection>[];
    final index = sections.isEmpty
        ? 0
        : sectionIndex.clamp(0, sections.length - 1);
    final section = sections.isEmpty ? null : sections[index];
    final next = index + 1 < sections.length ? sections[index + 1] : null;
    final hasPrevious = index > 0;
    // The last contents entry at or before this section is "where we are".
    final toc = book?.toc ?? const <EpubTocEntry>[];
    final tocIndex = toc.lastIndexWhere((entry) => entry.sectionIndex <= index);

    return ReaderShell(
      controller: shell,
      sectionKey: index,
      initialFraction: sectionStart,
      title: storyTitle.isNotEmpty ? storyTitle : (book?.title ?? ''),
      subtitle: section?.title ?? '',
      bottomLabel: section == null
          ? ''
          : '${section.title} · ${index + 1} / ${sections.length}',
      overallProgress: (fraction) =>
          book?.overallProgress(index, fraction) ?? fraction,
      error:
          bookAsync.error ??
          (book != null && sections.isEmpty
              ? 'This EPUB has no readable content.'
              : null),
      blocks: book == null || section == null
          ? null
          : _sectionBlocks(
              book: book,
              section: section,
              sectionIndex: index,
              appearance: appearance,
              nextTitle: next?.title == section.title ? null : next?.title,
              isLast: next == null,
              onInternalLink: _openSection,
            ),
      onProgress: book == null ? null : (value) => _onProgress(book, value),
      onNext: next == null ? null : () => _openSection(index + 1),
      onPrevious: hasPrevious ? () => _openSection(index - 1, start: 1) : null,
      drawer: ReaderContentsDrawer(
        items: [
          for (final entry in toc)
            ReaderTocItem(title: entry.title, depth: entry.depth.clamp(0, 3)),
        ],
        currentIndex: tocIndex,
        emptyMessage: 'No table of contents available.',
        onSelected: (selected) {
          Navigator.pop(context);
          _openSection(toc[selected].sectionIndex);
        },
      ),
    );
  }
}

List<Widget> _sectionBlocks({
  required EpubBookData book,
  required EpubSection section,
  required int sectionIndex,
  required ReaderAppearance appearance,
  required String? nextTitle,
  required bool isLast,
  required ValueChanged<int> onInternalLink,
}) {
  Widget image(String? src) {
    final bytes = src == null ? null : book.imageFor(section, src);
    if (bytes == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
    );
  }

  final extensions = [
    // Book images live inside the EPUB, not on the network.
    TagExtension(
      tagsToExtend: {'img'},
      builder: (context) => image(context.attributes['src']),
    ),
    // Covers are often an <svg> wrapping an <image>.
    TagExtension(
      tagsToExtend: {'svg'},
      builder: (context) {
        final found = context.element?.getElementsByTagName('image');
        final attributes = found == null || found.isEmpty
            ? null
            : found.first.attributes;
        return image(attributes?['xlink:href'] ?? attributes?['href']);
      },
    ),
  ];

  return [
    for (final block in section.blocks)
      ReaderHtml(
        html: block,
        appearance: appearance,
        extensions: extensions,
        onLinkTap: (url, _, _) {
          if (url == null) return;
          final target = book.sectionForLink(sectionIndex, url);
          if (target != null) onInternalLink(target);
        },
      ),
    // A chapter split over several files only gets a "next" note at its
    // real end; mid-chapter joins flow straight on.
    if (isLast || nextTitle != null)
      ReaderSectionEnd(
        appearance: appearance,
        nextTitle: nextTitle,
        nextLabel: 'NEXT',
      ),
  ];
}
