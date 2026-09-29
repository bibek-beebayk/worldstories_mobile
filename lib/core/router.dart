import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'main_shell.dart';
import 'modal_sheet_page.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/account_info_screen.dart';
import '../features/auth/presentation/auth_loading_screen.dart';
import '../features/auth/presentation/first_login_setup_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/catalogue/presentation/catalogue_screen.dart';
import '../features/discovery/presentation/discovery_screens.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/story/presentation/story_detail_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/reader/presentation/chapter_reader_screen.dart';
import '../features/reader/presentation/epub_reader_screen.dart';
import '../features/reader/presentation/pdf_reader_screen.dart';
import '../features/player/presentation/audiobook_player_screen.dart';
import '../features/player/presentation/read_along_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/reader/presentation/quick_read_screen.dart';
import '../features/blog/presentation/blog_list_screen.dart';
import '../features/blog/presentation/blog_detail_screen.dart';
import '../features/engagement/presentation/reviews_screen.dart';
import '../features/engagement/presentation/completion_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/stats_screen.dart';
import '../features/library/presentation/passport_screen.dart';
import '../features/library/presentation/journeys_screen.dart';
import '../features/library/presentation/moods_screen.dart';

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (previous, next) => refresh.notify());
  ref.onDispose(refresh.dispose);
  return refresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.uri.toString();
      final path = state.uri.path;
      final onSignIn = path == '/sign-in';
      final onAuthLoading = path == '/auth-loading';
      final onOnboarding = path == '/onboarding';

      if (auth.isLoading && !auth.hasValue) {
        if (onSignIn || onAuthLoading) return null;
        return Uri(
          path: '/auth-loading',
          queryParameters: {'from': location},
        ).toString();
      }

      final user = auth.value;
      if (user == null) {
        if (onSignIn) return null;
        final from = onAuthLoading
            ? state.uri.queryParameters['from'] ?? '/'
            : location;
        return Uri(
          path: '/sign-in',
          queryParameters: {'from': _safeDestination(from)},
        ).toString();
      }

      if (user.isFirstLogin) {
        if (onOnboarding) return null;
        final from = onSignIn || onAuthLoading
            ? state.uri.queryParameters['from']
            : location;
        return Uri(
          path: '/onboarding',
          queryParameters: {'from': _safeDestination(from)},
        ).toString();
      }

      if (onOnboarding) {
        return _safeDestination(state.uri.queryParameters['from']);
      }
      if (onSignIn || onAuthLoading) {
        return _safeDestination(state.uri.queryParameters['from']);
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => CatalogueScreen(
                  initialMoodSlugs: state.uri.queryParameters['moods'] ?? '',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'account-info',
                    builder: (context, state) => const AccountInfoScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth-loading',
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const FirstLoginSetupScreen(),
      ),
      GoRoute(
        path: '/story/:slug',
        pageBuilder: (context, state) => ModalSheetPage(
          key: state.pageKey,
          showDragHandle: false,
          child: StoryDetailScreen(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoverScreen(),
      ),
      GoRoute(
        path: '/trending',
        builder: (context, state) => const TrendingScreen(),
      ),
      GoRoute(
        path: '/story-map',
        builder: (context, state) => const StoryMapScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/read/:storySlug/:chapterSlug',
        builder: (context, state) => ChapterReaderScreen(
          storySlug: state.pathParameters['storySlug']!,
          chapterSlug: state.pathParameters['chapterSlug']!,
          startAtEnd: state.uri.queryParameters['at'] == 'end',
        ),
      ),
      GoRoute(
        path: '/read-pdf/:storySlug',
        builder: (context, state) =>
            PdfReaderScreen(storySlug: state.pathParameters['storySlug']!),
      ),
      GoRoute(
        path: '/read-epub/:storySlug',
        builder: (context, state) =>
            EpubReaderScreen(storySlug: state.pathParameters['storySlug']!),
      ),
      GoRoute(
        path: '/listen/:storySlug/:audioSlug',
        builder: (context, state) => AudiobookPlayerScreen(
          storySlug: state.pathParameters['storySlug']!,
          audioSlug: state.pathParameters['audioSlug']!,
        ),
      ),
      GoRoute(
        path: '/read-along/:storySlug/:audioSlug',
        builder: (context, state) => ReadAlongScreen(
          storySlug: state.pathParameters['storySlug']!,
          audioSlug: state.pathParameters['audioSlug']!,
        ),
      ),
      GoRoute(
        path: '/watch/:storySlug/:videoSlug',
        builder: (context, state) => VideoPlayerScreen(
          storySlug: state.pathParameters['storySlug']!,
          videoSlug: state.pathParameters['videoSlug']!,
        ),
      ),
      GoRoute(
        path: '/quick-read/:storySlug',
        builder: (context, state) =>
            QuickReadScreen(storySlug: state.pathParameters['storySlug']!),
      ),
      GoRoute(
        path: '/blog',
        builder: (context, state) => const BlogListScreen(),
      ),
      GoRoute(
        path: '/blog/:slug',
        builder: (context, state) =>
            BlogDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/story/:slug/reviews',
        builder: (context, state) =>
            ReviewsScreen(storySlug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/story/:slug/completion',
        builder: (context, state) =>
            CompletionScreen(storySlug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
      GoRoute(
        path: '/passport',
        builder: (context, state) => const PassportScreen(),
      ),
      GoRoute(
        path: '/passport/:code',
        builder: (context, state) =>
            PassportCountryScreen(countryCode: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/journeys',
        builder: (context, state) => const JourneysScreen(),
      ),
      GoRoute(
        path: '/journeys/:slug',
        builder: (context, state) =>
            JourneyDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(path: '/moods', builder: (context, state) => const MoodsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

String _safeDestination(String? destination) {
  if (destination == null ||
      !destination.startsWith('/') ||
      destination.startsWith('/sign-in') ||
      destination.startsWith('/auth-loading') ||
      destination.startsWith('/onboarding')) {
    return '/';
  }
  return destination;
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
