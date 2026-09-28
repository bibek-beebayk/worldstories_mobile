import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../engagement/presentation/completion_signals.dart';
import '../../story/presentation/story_title.dart';
import '../data/file_reading_progress_repository.dart';
import '../data/pdf_document_repository.dart';
import '../../../core/api_error_view.dart';

final pdfDocumentRepositoryProvider = Provider<PdfDocumentRepository>(
  (ref) => PdfDocumentRepository(ref.watch(apiClientProvider)),
);
final pdfBytesProvider = FutureProvider.family<Uint8List, String>(
  (ref, storySlug) =>
      ref.watch(pdfDocumentRepositoryProvider).fetchBytes(storySlug),
);

class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.storySlug});
  final String storySlug;
  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  PdfController? controller;
  int pageCount = 0;
  Timer? saveTimer;
  bool restored = false;

  bool get signedIn => ref.read(authControllerProvider).value != null;

  @override
  void dispose() {
    saveTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<int> _restoreInitialPage() async {
    if (!signedIn) return 1;
    try {
      final saved = await ref
          .read(fileReadingProgressRepositoryProvider)
          .fetch(widget.storySlug, FileReadingFormat.pdf);
      final page = int.tryParse(saved?.position ?? '');
      return page != null && page > 0 ? page : 1;
    } catch (_) {
      return 1;
    }
  }

  void _onPageChanged(int page) {
    if (!signedIn || pageCount <= 0) return;
    saveTimer?.cancel();
    saveTimer = Timer(
      const Duration(milliseconds: 700),
      () => _saveProgress(page),
    );
  }

  Future<void> _saveProgress(int page) async {
    if (!mounted) return;
    final progress = (page / pageCount).clamp(0.0, 1.0);
    try {
      final result = await ref
          .read(fileReadingProgressRepositoryProvider)
          .save(
            storySlug: widget.storySlug,
            format: FileReadingFormat.pdf,
            progress: progress,
            position: page.toString(),
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
    final storyTitle = watchStoryTitle(ref, widget.storySlug);
    return Scaffold(
      appBar: AppBar(
        title: Text(storyTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (pageCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ValueListenableBuilder<int>(
                  valueListenable: controller!.pageListenable,
                  builder: (context, page, _) => Text(
                    '$page / $pageCount',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ref
          .watch(pdfBytesProvider(widget.storySlug))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ApiErrorView(error: error),
            data: (bytes) => FutureBuilder<int>(
              future: _restoreInitialPage(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                controller ??= PdfController(
                  document: PdfDocument.openData(bytes),
                  initialPage: snapshot.data!,
                );
                return PdfView(
                  controller: controller!,
                  onDocumentLoaded: (document) =>
                      setState(() => pageCount = document.pagesCount),
                  onPageChanged: _onPageChanged,
                );
              },
            ),
          ),
    );
  }
}
