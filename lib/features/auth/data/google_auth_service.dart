import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config.dart';

final class GoogleAuthService {
  bool _initialized = false;

  Future<String> authenticate() async {
    if (AppConfig.googleServerClientId.isEmpty) {
      throw StateError('GOOGLE_SERVER_CLIENT_ID is not configured.');
    }
    final signIn = GoogleSignIn.instance;
    if (!_initialized) {
      await signIn.initialize(serverClientId: AppConfig.googleServerClientId);
      _initialized = true;
    }
    final account = await signIn.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google did not return an ID token.');
    }
    return token;
  }

  Future<void> signOut() async {
    if (_initialized) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
