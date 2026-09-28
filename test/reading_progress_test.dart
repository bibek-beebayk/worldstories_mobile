import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/reader/data/reading_progress_repository.dart';

void main() {
  test('parses reading progress and completion signals', () {
    final progress = ReadingProgress.fromJson({
      'chapter_slug': 'one',
      'progress': .4,
      'overall_progress': .2,
    });
    final result = ProgressSaveResult.fromJson({
      'story_completed': true,
      'unlocked_country': 'Nepal',
      'unlocked_achievements': [
        {'slug': 'first'},
      ],
    });
    expect(progress.progress, .4);
    expect(result.storyCompleted, isTrue);
    expect(result.unlockedAchievements, hasLength(1));
  });
}
