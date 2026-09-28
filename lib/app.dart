import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/app_theme.dart';

class WorldStoriesApp extends ConsumerWidget {
  const WorldStoriesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'WorldStories',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: ref.watch(routerProvider),
  );
}
