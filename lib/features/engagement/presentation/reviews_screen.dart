import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/review_repository.dart';
import '../../../core/api_error_view.dart';
import '../../../core/api_exception.dart';

final reviewPageProvider = FutureProvider.family<ReviewPage, String>(
  (ref, storySlug) => ref.read(reviewRepositoryProvider).fetch(storySlug),
);
final myReviewProvider = FutureProvider.family<Review?, String>(
  (ref, storySlug) => ref.read(reviewRepositoryProvider).fetchMine(storySlug),
);

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key, required this.storySlug});
  final String storySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).value != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      floatingActionButton: signedIn
          ? FloatingActionButton.extended(
              onPressed: () => _openReviewEditor(context, ref),
              icon: const Icon(Icons.edit),
              label: const Text('Write a review'),
            )
          : null,
      body: ref
          .watch(reviewPageProvider(storySlug))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ApiErrorView(error: error),
            data: (page) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(reviewPageProvider(storySlug).future),
                child: page.reviews.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 120),
                        child: Center(child: Text('No reviews yet.')),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: page.reviews.length,
                    itemBuilder: (context, index) {
                      final review = page.reviews[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    review.username,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (star) => Icon(
                                        star < review.rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 18,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (review.comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(review.comment),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ),
          ),
    );
  }

  Future<void> _openReviewEditor(BuildContext context, WidgetRef ref) async {
    final existing = await ref.read(myReviewProvider(storySlug).future);
    if (!context.mounted) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReviewEditorSheet(
        storySlug: storySlug,
        existing: existing,
      ),
    );
    if (result == true) {
      ref.invalidate(reviewPageProvider(storySlug));
      ref.invalidate(myReviewProvider(storySlug));
    }
  }
}

class _ReviewEditorSheet extends ConsumerStatefulWidget {
  const _ReviewEditorSheet({required this.storySlug, required this.existing});
  final String storySlug;
  final Review? existing;
  @override
  ConsumerState<_ReviewEditorSheet> createState() =>
      _ReviewEditorSheetState();
}

class _ReviewEditorSheetState extends ConsumerState<_ReviewEditorSheet> {
  late int rating = widget.existing?.rating ?? 5;
  late final commentController = TextEditingController(
    text: widget.existing?.comment ?? '',
  );
  bool saving = false;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => saving = true);
    try {
      final repository = ref.read(reviewRepositoryProvider);
      if (widget.existing == null) {
        await repository.submit(
          storySlug: widget.storySlug,
          rating: rating,
          comment: commentController.text.trim(),
        );
      } else {
        await repository.updateMine(
          storySlug: widget.storySlug,
          rating: rating,
          comment: commentController.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.existing == null ? 'Write a review' : 'Edit your review',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(
            5,
            (index) => IconButton(
              icon: Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              tooltip: '${index + 1} star${index == 0 ? '' : 's'}',
              onPressed: () => setState(() => rating = index + 1),
            ),
          ),
        ),
        TextField(
          controller: commentController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Share your thoughts (optional)',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving ? null : _submit,
          child: saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save review'),
        ),
      ],
    ),
  );
}
