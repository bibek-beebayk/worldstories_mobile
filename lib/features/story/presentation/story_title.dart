import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'story_detail_screen.dart';

String watchStoryTitle(WidgetRef ref, String slug) {
  final fetchedTitle = ref.watch(storyDetailProvider(slug)).value?.title.trim();
  return fetchedTitle == null || fetchedTitle.isEmpty
      ? titleFromStorySlug(slug)
      : fetchedTitle;
}

String titleFromStorySlug(String slug) => slug
    .split('-')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
