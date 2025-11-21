# attendanceapp

<!-- ...existing code... -->

## Overview

AttendanceApp is a Flutter application for managing and tracking attendance sessions (e.g., classes, events, trainings). It enables authorized users to create sessions and participants to check in securely (e.g., via QR code, manual code, or geo-based validation).

## Core Features

- Session creation & scheduling
- User authentication (Firebase Auth)
- QR code generation & scanning
- Manual check-in fallback
- Offline data capture with later sync
- Attendance analytics dashboard
- Role-based access (admin / student / staff (if applied))
- Export (CSV / XLSX) (optional)
- Notifications (placeholder if implemented)
- Dark / light theme

## Tech Stack

- Flutter (stable) – UI framework
- State management: (Riverpod / Provider / Bloc)
- Local persistence: (SharedPreferences)
- Remote backend: (Firebase)
- QR: (placeholder: e.g. qr_flutter, mobile_scanner)
- Dependency injection: (placeholder if used)

## Architecture

- Layered: presentation / application / domain / data
- Immutable models + JSON serialization
- Centralized error/result handling
- Separation of concerns for testability

## Project Setup

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Run: `flutter --version` (ensure stable channel)
3. Fetch packages: `flutter pub get`
4. Configure environment file(s) (see below).
5. Run app: `flutter run`
6. For release builds:
   - Android: `flutter build apk --release`
   - iOS: `flutter build ipa` (macOS only)

## Environment Configuration

Create a file (example): `lib/config/app_config.dart` or use `.env` with `flutter_dotenv`.
Placeholders:

- API_BASE_URL=
- AUTH_PROVIDER=
- ANALYTICS_ENABLED=true|false

## Folder Structure (simplified)

```
lib/
  main.dart
  core/               # constants, utilities
  features/
    attendance/
      data/
      domain/
      presentation/
    auth/
    session/
  widgets/
  config/
assets/
test/
```

## Running Tests

- Unit: `flutter test`
- Widget: `flutter test --tags widget`
- Integration: `flutter test integration_test`
  (Ensure integration_test/ directory exists)

## Linting & Formatting

- Format: `dart format .`
- Analyze: `flutter analyze`
- Recommended: enable `analysis_options.yaml` (placeholder)

## CI/CD (placeholder)

Suggested steps:

- Install Flutter
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- Build artifacts (release)

## Security & Privacy

- Validate all session creation actions server-side.
- Obfuscate release build if needed: `flutter build apk --obfuscate --split-debug-info=build/debug`
- Do not log PII.

## Roadmap (fill as needed)

- [ ] Push notifications
- [ ] Qr check-in
- [ ] Multi-tenant support

## Contributing

1. Fork & branch (`feat/<short-description>`).
2. Keep PRs small.
3. Include related tests.
4. Follow commit convention (placeholder: e.g. Conventional Commits).

## Troubleshooting

- Stuck at build: run `flutter clean && flutter pub get`
- Plugin mismatch: update `minSdkVersion` in `android/app/build.gradle`
- iOS Pod issues: `cd ios && pod install --repo-update`

## License

(placeholder: e.g. MIT)

## References

- Flutter docs: https://docs.flutter.dev/
- State management patterns: https://docs.flutter.dev/development/data-and-backend/state-mgmt

## Members

- Christian Misal – Project Manager
- Kenneth D. Lico – Front-End Engineer
- John Lyold C. Lozada - Backdancer
- Joseph Claire L. Paquinol – Full-Stack Engineer

## Fill These Placeholders

Replace all sections marked (placeholder) with actual technologies in your current system.

<!-- ...existing code... -->
