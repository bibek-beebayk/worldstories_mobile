import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/story/data/story_detail_repository.dart';

void main() {
  test('parses story detail media and taxonomy lists', () {
    final story = StoryDetail.fromJson({
      'title': 'The Raven',
      'slug': 'the-raven',
      'story_type': 'Poetry',
      'language': 'en',
      'rating': 4.7,
      'views': 12,
      'author': {
        'name': 'Edgar Allan Poe',
        'bio': 'American writer and poet.',
        'image': 'https://example.com/poe.jpg',
        'stories_count': 4,
      },
      'chapters': [
        {'title': 'The Raven', 'slug': 'the-raven', 'order': 1},
      ],
      'audios': [
        {'title': 'Audio', 'slug': 'audio'},
      ],
      'videos': [],
      'tags': [
        {'name': 'Gothic'},
      ],
      'themes': [
        {'name': 'Grief'},
      ],
      'similar_stories': [],
    });
    expect(story.author, 'Edgar Allan Poe');
    expect(story.authorDetails?.bio, 'American writer and poet.');
    expect(story.authorDetails?.storiesCount, 4);
    expect(story.chapters.single.order, 1);
    expect(story.tags, ['Gothic']);
  });
}
