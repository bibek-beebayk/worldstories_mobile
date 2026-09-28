import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/application/analytics_service.dart';
import '../../analytics/data/analytics_repository.dart';
import '../data/gamification_repository.dart';
import '../../../core/api_error_view.dart';

final passportProvider = FutureProvider<PassportSummary>(
  (ref) => ref.read(gamificationRepositoryProvider).fetchPassport(),
);
final passportCountryProvider =
    FutureProvider.family<PassportCountryDetail, String>(
      (ref, code) =>
          ref.read(gamificationRepositoryProvider).fetchPassportCountry(code),
    );

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(passportProvider, (previous, next) {
      if (previous == null) {
        ref.read(analyticsServiceProvider).track(AnalyticsEventType.passportViewed);
      }
    });
    return Scaffold(
    appBar: AppBar(title: const Text('Story Passport')),
    body: ref
        .watch(passportProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (passport) => RefreshIndicator(
            onRefresh: () => ref.refresh(passportProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(
                      label: 'Explored',
                      value: '${passport.countriesExplored}/${passport.countriesAvailable}',
                    ),
                    _Stat(label: 'Stories finished', value: '${passport.storiesCompleted}'),
                  ],
                ),
                const Divider(height: 32),
                ...passport.countries.map(
                  (country) => ListTile(
                    leading: Icon(
                      country.explored ? Icons.flag : Icons.flag_outlined,
                      color: country.explored ? Colors.green : null,
                    ),
                    title: Text(country.name),
                    subtitle: Text(
                      '${country.storiesCompleted}/${country.storiesAvailable} stories completed',
                    ),
                    onTap: () => context.push('/passport/${country.code}'),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
  }
}

class PassportCountryScreen extends ConsumerWidget {
  const PassportCountryScreen({super.key, required this.countryCode});
  final String countryCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Passport')),
    body: ref
        .watch(passportCountryProvider(countryCode))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(error: error),
          data: (detail) => RefreshIndicator(
            onRefresh: () =>
                ref.refresh(passportCountryProvider(countryCode).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  detail.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${detail.storiesCompleted}/${detail.storiesAvailable} stories completed',
                ),
                if (detail.completed.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Completed', style: Theme.of(context).textTheme.titleLarge),
                  ...detail.completed.map(
                    (story) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(story.title),
                      onTap: story.slug.isEmpty
                          ? null
                          : () => context.push('/story/${story.slug}'),
                    ),
                  ),
                ],
                if (detail.continueExploring.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Continue exploring',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...detail.continueExploring.map(
                    (story) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_stories),
                      title: Text(story.title),
                      onTap: story.slug.isEmpty
                          ? null
                          : () => context.push('/story/${story.slug}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
