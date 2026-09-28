import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/reader/application/epub_progress.dart';

void main() {
  test('opening an epub does not report it as completed', () {
    final progress = calculateEpubProgress(
      currentIndex: 0,
      totalItems: 20,
      reachedEnd: false,
    );

    expect(progress, 0.05);
  });

  test(
    'the last item remains below the completion threshold before the end',
    () {
      final progress = calculateEpubProgress(
        currentIndex: 19,
        totalItems: 20,
        reachedEnd: false,
      );

      expect(progress, 0.99);
    },
  );

  test('reaching the end after reading reports full completion', () {
    final progress = calculateEpubProgress(
      currentIndex: 19,
      totalItems: 20,
      reachedEnd: true,
    );

    expect(progress, 1);
  });
}
