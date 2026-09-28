import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../reader/data/quick_read_progress_repository.dart'
    show SimpleProgress;
import '../data/blog_progress_repository.dart';
import '../data/blog_repository.dart';
import '../../../core/api_error_view.dart';
import '../../../shared/widgets/cached_app_image.dart';

final blogDetailProvider = FutureProvider.family<BlogDetail, String>(
  (ref, slug) => ref.read(blogRepositoryProvider).fetchDetail(slug),
);

class BlogDetailScreen extends ConsumerStatefulWidget {
  const BlogDetailScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends ConsumerState<BlogDetailScreen> {
  final scrollController = ScrollController();
  Timer? saveTimer;
  bool restored = false;
  bool visitTracked = false;

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
      saved = await ref.read(blogProgressRepositoryProvider).fetch(widget.slug);
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
          .read(blogProgressRepositoryProvider)
          .save(blogSlug: widget.slug, progress: progress);
    } catch (_) {
      // Progress is best-effort during reading; the next scroll retries.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blog')),
    body: ref
        .watch(blogDetailProvider(widget.slug))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (blog) {
            _restore();
            if (!visitTracked) {
              visitTracked = true;
              ref
                  .read(analyticsServiceProvider)
                  .track(AnalyticsEventType.visit, blogSlug: blog.slug);
            }
            return RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(blogDetailProvider(widget.slug).future),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (blog.coverImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedAppImage(
                            imageUrl: blog.coverImage!,
                            fit: BoxFit.cover,
                            decodeWidth: 1200,
                            diskCacheWidth: 1200,
                            error: (_) =>
                                const ColoredBox(color: Colors.black12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      blog.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (blog.authorName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        blog.authorName!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                    const Divider(height: 32),
                    Html(
                      data: blog.content,
                      style: {
                        'body': Style(
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                          fontSize: FontSize(17),
                          lineHeight: const LineHeight(1.65),
                        ),
                        'p': Style(margin: Margins.only(bottom: 16)),
                        'img': Style(
                          width: Width(100, Unit.percent),
                          height: Height.auto(),
                        ),
                      },
                    ),
                    if (blog.linkedStories.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Related stories',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ...blog.linkedStories.map(
                        (story) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.auto_stories),
                          title: Text(story.title),
                          onTap: () => context.push('/story/${story.slug}'),
                        ),
                      ),
                    ],
                    if (blog.linkedBlogs.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'More from the blog',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ...blog.linkedBlogs.map(
                        (post) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.article_outlined),
                          title: Text(post.title),
                          subtitle: post.excerpt.isEmpty
                              ? null
                              : Text(
                                  post.excerpt,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () =>
                              context.pushReplacement('/blog/${post.slug}'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
  );
}
