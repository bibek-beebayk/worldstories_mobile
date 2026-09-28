import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error_view.dart';
import '../../../core/providers.dart';
import '../data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiClientProvider)),
);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final controller = TextEditingController();
  String query = '';
  int titlePage = 1;
  int authorPage = 1;
  int chapterPage = 1;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit([String? _]) => setState(() {
    query = controller.text.trim();
    titlePage = authorPage = chapterPage = 1;
  });

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Titles'),
            Tab(text: 'Authors'),
            Tab(text: 'Chapters'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: submit,
              decoration: InputDecoration(
                hintText: 'Search titles, authors, and chapters…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: submit,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Search',
                ),
              ),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? const Center(
                    child: Text('Enter a title, author, or phrase to search.'),
                  )
                : FutureBuilder<SearchResults>(
                    future: ref
                        .read(searchRepositoryProvider)
                        .search(
                          query,
                          titlePage: titlePage,
                          authorPage: authorPage,
                          chapterPage: chapterPage,
                        ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ApiErrorView(
                          error: snapshot.error!,
                          onRetry: () => setState(() {}),
                        );
                      }
                      final data = snapshot.data!;
                      return TabBarView(
                        children: [
                          _ResultPage(
                            page: data.titles.page,
                            pages: data.titles.pages,
                            onPrevious: () => setState(() => titlePage--),
                            onNext: () => setState(() => titlePage++),
                            children: data.titles.results
                                .map(
                                  (story) => ListTile(
                                    onTap: () =>
                                        context.push('/story/${story.slug}'),
                                    leading: const Icon(Icons.auto_stories),
                                    title: Text(story.title),
                                    subtitle: story.author == null
                                        ? null
                                        : Text(story.author!),
                                    trailing: const Icon(Icons.chevron_right),
                                  ),
                                )
                                .toList(),
                          ),
                          _ResultPage(
                            page: data.authors.page,
                            pages: data.authors.pages,
                            onPrevious: () => setState(() => authorPage--),
                            onNext: () => setState(() => authorPage++),
                            children: data.authors.results
                                .map(
                                  (author) => ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(author.name),
                                    subtitle: Text('${author.count} stories'),
                                  ),
                                )
                                .toList(),
                          ),
                          _ResultPage(
                            page: data.chapters.page,
                            pages: data.chapters.pages,
                            onPrevious: () => setState(() => chapterPage--),
                            onNext: () => setState(() => chapterPage++),
                            children: data.chapters.results
                                .map(
                                  (chapter) => ListTile(
                                    onTap: () => context.push(
                                      '/story/${chapter.storySlug}',
                                    ),
                                    leading: const Icon(Icons.article),
                                    title: Text(chapter.chapterTitle),
                                    subtitle: Text(
                                      '${chapter.storyTitle}\n${_plainText(chapter.excerpt)}',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    isThreeLine: true,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );

  static String _plainText(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ResultPage extends StatelessWidget {
  const _ResultPage({
    required this.children,
    required this.page,
    required this.pages,
    required this.onPrevious,
    required this.onNext,
  });
  final List<Widget> children;
  final int page;
  final int pages;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: children.isEmpty
            ? const Center(child: Text('No results found.'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: children.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) => children[index],
              ),
      ),
      if (pages > 1)
        SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: page > 1 ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
              ),
              Text('Page $page of $pages'),
              IconButton(
                onPressed: page < pages ? onNext : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
              ),
            ],
          ),
        ),
    ],
  );
}
