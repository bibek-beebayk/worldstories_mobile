# WorldStories Mobile architecture

The app uses a feature-first Flutter structure with a small shared `core/` layer.

- **State:** Riverpod. Async providers expose explicit loading, data, and error states and keep
  repositories out of widgets.
- **Navigation:** `go_router`. Routes are declared centrally now and can grow into authenticated
  route guards without replacing the navigation stack.
- **Networking:** Dio behind `ApiClient`; repositories own endpoint-specific parsing. The client
  attaches JWT access tokens, performs one retry after a 401, persists both rotated tokens before
  retrying, and maps throttling separately from general request failures.
- **Secrets:** `flutter_secure_storage` only. Access and refresh tokens are never placed in shared
  preferences or logs.
- **Non-sensitive local data:** `shared_preferences` for small settings and stable identifiers.
  Offline content/progress storage is deferred until Milestone 11 is confirmed.
- **Configuration:** the production API is the default and can be overridden without source edits
  using `--dart-define=API_BASE_URL=https://example.test/api/`.

Feature folders split `data` from `presentation`. Models remain feature-local until they are truly
shared, avoiding a large global model bucket with accidental coupling.
