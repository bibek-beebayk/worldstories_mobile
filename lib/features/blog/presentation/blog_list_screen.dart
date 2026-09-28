import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/blog_repository.dart';
import '../../../core/api_error_view.dart';
import '../../../shared/widgets/cached_app_image.dart';

final blogPageProvider = FutureProvider.family<BlogPage, int>(
  (ref, page) => ref.read(blogRepositoryProvider).fetchList(page: page),
);

class BlogListScreen extends ConsumerStatefulWidget {
  const BlogListScreen({super.key});
  @override
  ConsumerState<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends ConsumerState<BlogListScreen> {
  int page = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blog')),
    body: ref
        .watch(blogPageProvider(page))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (result) => Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(blogPageProvider(page).future),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: result.posts.length,
                    itemBuilder: (context, index) {
                      final post = result.posts[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () => context.push('/blog/${post.slug}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (post.coverImage != null)
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: CachedAppImage(
                                    imageUrl: post.coverImage!,
                                    fit: BoxFit.cover,
                                    decodeWidth: 900,
                                    diskCacheWidth: 1200,
                                    error: (_) =>
                                        const ColoredBox(color: Colors.black12),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    if (post.authorName != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        post.authorName!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (post.excerpt.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        post.excerpt,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous page',
                      onPressed: page > 1
                          ? () => setState(() => page -= 1)
                          : null,
                    ),
                    Text('Page ${result.page} of ${result.pages}'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next page',
                      onPressed: page < result.pages
                          ? () => setState(() => page += 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
  );
}
