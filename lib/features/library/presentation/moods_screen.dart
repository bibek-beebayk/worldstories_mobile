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
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: moods.length,
              itemBuilder: (context, index) {
                final mood = moods[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(mood.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 8),
                        Text(
                          mood.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${mood.storiesCount} stories',
                          style: Theme.of(context).textTheme.bodySmall,
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
