double calculateEpubProgress({
  required int currentIndex,
  required int totalItems,
  required bool reachedEnd,
}) {
  if (totalItems <= 0) return 0;
  if (reachedEnd) return 1;

  final position = (currentIndex + 1) / totalItems;
  return position.clamp(0.0, 0.99).toDouble();
}
