import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);
final googleAuthServiceProvider = Provider<GoogleAuthService>(
  (ref) => GoogleAuthService(),
);

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);

class AuthController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final repository = ref.watch(authRepositoryProvider);
    if (!await repository.hasSession()) return null;
    try {
      final profile = await repository.fetchProfile();
      final onboardingRequired = await ref
          .read(tokenStoreProvider)
          .readOnboardingRequired();
      return profile.copyWith(isFirstLogin: onboardingRequired);
    } on UnauthorizedException {
      await ref.read(tokenStoreProvider).clear();
      return null;
    }
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final token = await ref.read(googleAuthServiceProvider).authenticate();
      return ref.read(authRepositoryProvider).signInWithGoogleToken(token);
    });
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
  }) async {
    final profile = await ref
        .read(authRepositoryProvider)
        .updateProfile(
          displayName: displayName,
          bio: bio,
          avatarUrl: avatarUrl,
        );
    state = AsyncData(profile);
  }

  Future<void> completeOnboarding({
    required String username,
    required String displayName,
    required Set<int> preferredGenreIds,
  }) async {
    final profile = await ref
        .read(authRepositoryProvider)
        .completeOnboarding(
          username: username,
          displayName: displayName,
          preferredGenreIds: preferredGenreIds,
        );
    state = AsyncData(profile);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      await ref.read(googleAuthServiceProvider).signOut();
      state = const AsyncData(null);
    }
  }
}
