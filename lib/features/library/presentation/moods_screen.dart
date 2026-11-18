import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mood_repository.dart';
import '../../../core/api_error_view.dart';

final moodListProvider = FutureProvider<List<Mood>>(
  (ref) => ref.read(moodRepositoryProvider).fetchList(),
);

// A read-only browse of moods for now — the API supports filtering the
// catalogue by mood (`?moods=slug1,slug2`), but wiring a mood tap through to
// a pre-filtered catalogue view needs the catalogue screen to accept an
// initial filter, which is out of scope for this pass. Worth revisiting.
class MoodsScreen extends ConsumerWidget {
  const MoodsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Moods')),
    body: ref
        .watch(moodListProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (moods) => RefreshIndicator(
            onRefresh: () => ref.refresh(moodListProvider.future),
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 156,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: moods.length,
              itemBuilder: (context, index) {
                final mood = moods[index];
                final colors = _moodColors(mood.slug);
                return Card(
                  color: colors.background,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.foreground.withValues(alpha: 0.18)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(mood.icon, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          mood.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.foreground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          '${mood.storiesCount} stories',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.foreground.withValues(alpha: 0.75),
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
  );
}

typedef _MoodColors = ({Color background, Color foreground});

const _moodPalette = <_MoodColors>[
  (background: Color(0xFFFFE4E8), foreground: Color(0xFF9F1239)), // rose
  (background: Color(0xFFFFEDD5), foreground: Color(0xFF9A3412)), // orange
  (background: Color(0xFFFEF9C3), foreground: Color(0xFF854D0E)), // yellow
  (background: Color(0xFFDCFCE7), foreground: Color(0xFF166534)), // green
  (background: Color(0xFFCCFBF1), foreground: Color(0xFF115E59)), // teal
  (background: Color(0xFFE0F2FE), foreground: Color(0xFF075985)), // sky
  (background: Color(0xFFE0E7FF), foreground: Color(0xFF3730A3)), // indigo
  (background: Color(0xFFF3E8FF), foreground: Color(0xFF6B21A8)), // purple
  (background: Color(0xFFFCE7F3), foreground: Color(0xFF9D174D)), // pink
];

/// A stable color per mood, derived from its slug so it never changes
/// between launches or list order.
_MoodColors _moodColors(String slug) {
  var hash = 0;
  for (final unit in slug.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _moodPalette[hash % _moodPalette.length];
}
