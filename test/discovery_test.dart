import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/discovery/data/discovery_repository.dart';

void main() {
  test('parses story types in discover data', () {
    final data = DiscoverData.fromJson({
      'genres': [],
      'categories': [],
      'story_types': [
        {'id': 2, 'name': 'Short Story', 'stories_count': 8},
      ],
      'most_viewed': [],
      'highest_rated': [],
      'new_releases': [],
      'hidden_gems': [],
    });

    expect(data.storyTypes.single.name, 'Short Story');
    expect(data.storyTypes.single.count, 8);
  });

  test('parses story map country totals', () {
    final data = StoryMapData.fromJson({
      'total_stories': 4,
      'countries': [
        {'code': 'NP', 'name': 'Nepal', 'stories_count': 2},
      ],
    });
    expect(data.totalStories, 4);
    expect(data.countries.single.code, 'NP');
  });
}
