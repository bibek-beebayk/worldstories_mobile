import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../data/reaction_repository.dart';

final reactionSummaryProvider = FutureProvider.family<ReactionSummary, String>(
  (ref, storySlug) => ref.read(reactionRepositoryProvider).fetch(storySlug),
);

const _reactionLabels = {
  ReactionType.loved: ('❤️', 'Loved it'),
  ReactionType.funny: ('😂', 'Funny'),
  ReactionType.surprising: ('😮', 'Surprising'),
  ReactionType.emotional: ('😢', 'Emotional'),
  ReactionType.thoughtProvoking: ('🧠', 'Thought-provoking'),
};

class ReactionsRow extends ConsumerWidget {
  const ReactionsRow({super.key, required this.storySlug});
  final String storySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(reactionSummaryProvider(storySlug))
      .when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (summary) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReactionType.values.map((type) {
            final match = summary.reactions.firstWhere(
              (item) => item.type == type.wireValue,
              orElse: () => ReactionCount(
                type: type.wireValue,
                label: _reactionLabels[type]!.$2,
                count: 0,
              ),
            );
            final selected = summary.myReaction == type.wireValue;
            return ChoiceChip(
              label: Text(
                '${_reactionLabels[type]!.$1} ${match.count > 0 ? match.count : ''}',
              ),
              selected: selected,
              onSelected: (_) async {
                if (ref.read(authControllerProvider).value == null) {
                  context.push('/sign-in');
                  return;
                }
                try {
                  final result = await ref
                      .read(reactionRepositoryProvider)
                      .toggle(storySlug, type);
                  if (result.myReaction == type.wireValue) {
                    ref
                        .read(analyticsServiceProvider)
                        .track(
                          AnalyticsEventType.reactionAdded,
                          storySlug: storySlug,
                          metadata: {'reaction_type': type.wireValue},
                        );
                  }
                  ref.invalidate(reactionSummaryProvider(storySlug));
                } catch (_) {
                  // Best-effort; leave the previous summary displayed.
                }
              },
            );
          }).toList(),
        ),
      );
}
