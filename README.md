# WorldStories Mobile

## Local Google Sign-In configuration

Edit `config/local.json` once and replace the placeholder with the Google **Web OAuth client ID**:

```json
{
  "GOOGLE_SERVER_CLIENT_ID": "123456789-example.apps.googleusercontent.com"
}
```

The file is ignored by Git. Run or build with the wrappers so its values are loaded automatically:

```bash
./tool/run_android.sh
./tool/build_android.sh
```

Extra Flutter arguments can follow the script, for example `./tool/run_android.sh -d emulator-5554`.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
