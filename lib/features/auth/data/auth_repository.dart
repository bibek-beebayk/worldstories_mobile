import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/token_store.dart';

final class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.isFirstLogin = false,
  });
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool isFirstLogin;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'].toString(),
    email: json['email'] as String? ?? '',
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String?,
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );

  UserProfile copyWith({bool? isFirstLogin}) => UserProfile(
    id: id,
    email: email,
    username: username,
    displayName: displayName,
    bio: bio,
    avatarUrl: avatarUrl,
    isFirstLogin: isFirstLogin ?? this.isFirstLogin,
  );
}

final class OnboardingGenre {
  const OnboardingGenre({required this.id, required this.name});

  final int id;
  final String name;

  factory OnboardingGenre.fromJson(Map<String, dynamic> json) =>
      OnboardingGenre(id: json['id'] as int, name: json['name'] as String);
}

final class AuthRepository {
  const AuthRepository(this._client, this._tokens);
  final ApiClient _client;
  final TokenStore _tokens;

  Future<bool> hasSession() async =>
      (await _tokens.readRefreshToken())?.isNotEmpty == true;

  Future<UserProfile> signInWithGoogleToken(String idToken) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        'auth/google-login/',
        data: {'token': idToken},
      );
      final data = response.data!;
      await _tokens.saveTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      );
      final responseUser = data['user'] as Map?;
      final isFirstLogin = responseUser?['is_first_login'] as bool? ?? false;
      if (isFirstLogin) {
        await _tokens.setOnboardingRequired(true);
      }
      final profile = await fetchProfile();
      return profile.copyWith(isFirstLogin: isFirstLogin);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<UserProfile> fetchProfile() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('auth/me/');
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<UserProfile> updateProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
  }) async {
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        'auth/me/',
        data: {
          'display_name': displayName,
          'bio': bio,
          'avatar_url': avatarUrl,
        },
      );
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<OnboardingGenre>> fetchOnboardingGenres() async {
    try {
      final response = await _client.dio.get<List<dynamic>>('genres/');
      return (response.data ?? const [])
          .map(
            (item) => OnboardingGenre.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<bool> usernameAvailable(String username) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        'auth/username-available/',
        queryParameters: {'username': username},
      );
      return response.data?['available'] as bool? ?? false;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<UserProfile> completeOnboarding({
    required String username,
    required String displayName,
    required Set<int> preferredGenreIds,
  }) async {
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        'auth/me/',
        data: {
          'username': username,
          'display_name': displayName,
          'preferred_genres': preferredGenreIds.toList(),
        },
      );
      final profile = UserProfile.fromJson(response.data!);
      await _tokens.setOnboardingRequired(false);
      return profile;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    try {
      if (refresh != null) {
        await _client.dio.post<void>(
          'auth/logout/',
          data: {'refresh': refresh},
        );
      }
    } finally {
      await _tokens.clear();
    }
  }
}
