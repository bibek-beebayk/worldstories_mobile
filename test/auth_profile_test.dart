import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/auth/data/auth_repository.dart';

void main() {
  test('profile is not marked as first login by default', () {
    final profile = UserProfile.fromJson({
      'id': 7,
      'email': 'reader@example.com',
      'username': 'reader',
      'display_name': 'Reader',
    });

    expect(profile.isFirstLogin, isFalse);
    expect(profile.id, '7');
  });

  test('first-login flag can be attached to the fetched profile', () {
    const profile = UserProfile(
      id: '7',
      email: 'reader@example.com',
      username: 'reader',
      displayName: 'Reader',
    );

    final firstLoginProfile = profile.copyWith(isFirstLogin: true);

    expect(firstLoginProfile.isFirstLogin, isTrue);
    expect(firstLoginProfile.email, profile.email);
    expect(firstLoginProfile.displayName, profile.displayName);
  });

  test('parses a genre used during onboarding', () {
    final genre = OnboardingGenre.fromJson({'id': 3, 'name': 'Folklore'});

    expect(genre.id, 3);
    expect(genre.name, 'Folklore');
  });
}
