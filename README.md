# Attendance App

<!-- ...existing code... -->

(assets/pics/qrAttendance.jpg)

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

## Members

- Christian Misal – Project Empress
- Kenneth D. Lico – Front-End Engineer
- John Lyold C. Lozada - Backdancer
- Joseph Claire L. Paquinol – Full-Stack Engineer

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

## Current Implementation Summary

This codebase currently includes:

- Daily attendance records stored in Firestore under `Student/{studentDocId}/Record/{dd MMMM yyyy}`.
- QR-based check-in/out (first scan sets `checkIn` + `qrCode`, second sets `checkOut` + `qrCodeOut`).
- Location capture (latitude/longitude + reverse geocoded address when available).
- Profile editing with image upload to Firebase Storage (`profilePictures/{studentDocId}.jpg`).
- Role-based authentication (student / teacher / admin) via Firebase Auth email & password.
- Attendance calendar with month filter.
- Legacy StudentID-only login deprecated (`loginscreen.dart` retained only as a stub).
- Account verification workflow: new users start with `status: pending` until approved by an admin/teacher.

## Role-Based Authentication

Flow:

1. User registers or signs in on `RoleLoginScreen` with email, password, and selected role. Students also provide their Student ID to link to the existing `Student` document.
2. A document is created/updated in `Users` collection: `{ uid, email, role, studentId? }`.
3. `AuthService` hydrates global user context (`model/user.dart`).
4. `main.dart` routes based on `User.role`:

- `student` -> `Homescreen` (attendance features)
- `teacher` -> `TeacherHome` (placeholder)
- `admin` -> `AdminHome` (placeholder)

5. Legacy `LoginScreen` removed; do not use StudentID/password direct login anymore.
6. Pending accounts are routed to a holding screen; upon approval they receive a push notification (FCM) and gain access.

Important Firestore Collections:

- `Student` (existing student metadata)
- `Users` (auth mapping & role)
- `Student/{studentDocId}/Record` (daily attendance docs)

## QR Attendance Workflow

1. Student taps the scan button on Today Screen.
2. First successful scan: sets `checkIn`, `qrCode`, and captures location/address if ready.
3. Second successful scan (same day): sets `checkOut`, `qrCodeOut`.
4. Document ID format: `dd MMMM yyyy` (e.g., `07 March 2025`).
5. Fields stored: `date`, `checkIn`, `checkOut`, `location` (string), `qrCode`, `qrCodeOut`.
6. If location not yet resolved at scan time, coordinates populate later (merge update) when reverse geocode completes.

## Firebase Setup & CONFIGURATION_NOT_FOUND Fix

If you see `FirebaseAuthException: CONFIGURATION_NOT_FOUND` or reCAPTCHA internal errors during sign-in:

Checklist:

1. Confirm `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) match the app's package/bundle IDs in Firebase console.
2. Add SHA-1 and SHA-256 fingerprints for the Android app in Firebase console (Project Settings > Android App). Re-download `google-services.json` after adding.
3. Enable Email/Password provider in Firebase Console > Authentication > Sign-in method.
4. If using Android API 33+, ensure Play Integrity/SafetyNet settings are enabled (Firebase may require updated captcha flows).
5. Run: `flutter clean ; flutter pub get` then rebuild.
6. Verify dependencies in `pubspec.yaml`: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `mobile_scanner`, `location`, `geocoding`.
7. Ensure `Firebase.initializeApp()` is called before any Auth/Firestore usage (check `main.dart`).
8. For emulator usage, avoid network blocks (no VPN/proxy that strips requests).
9. iOS: Confirm APNs certs not required for email/password; just ensure the plist file is present and bundle ID matches.
10. Web (if targeting): Add authorized domains and configure reCAPTCHA if using phone auth (not required for email/password only).

After changes, reinstall app on device to clear stale cached configs.

## Account Verification Workflow

1. Registration writes `Users/{uid}` with fields: `uid,email,role,status:'pending',studentId?,createdAt`.
2. Pending users see a waiting screen (`PendingVerificationScreen`).
3. Admin/Teacher opens `VerificationScreen` to Approve or Reject.
4. Approval sets `status:'approved'`. Firestore trigger (Cloud Function) sends FCM notification to the stored `fcmToken`.
5. Client's next token refresh hydrates `status`, unlocking normal routing.
6. Optional: Add custom claim `approved:true` server-side for rules efficiency.

## Social Authentication & Credential Completion

Social providers (Google / Facebook) allow faster onboarding while still enforcing role assignment and approval.

Flow:

1. User taps a social provider button on `RoleLoginScreen`.
2. After successful provider sign-in, a `Users/{uid}` doc is created if absent with: `uid, email, providers:[google|facebook], status:'incomplete', createdAt`.
3. App routes user with `status:'incomplete'` to `CompleteCredentialsScreen`.
4. User selects a role (student / teacher / admin) and (if student) enters `studentId`.
5. Submission updates doc (`role`, optional `studentId`, status changes to `pending`). Student `Student` doc is created if missing.
6. Admin/Teacher approval flips `status` to `approved` → normal dashboard access; rejection sets `rejected` and UI can display a resolution message.

Doc Fields Summary (Users):

```
uid: string
email: string
providers: ["password", "google", "facebook"]
role: student|teacher|admin (after completion)
studentId: string (students only)
status: incomplete|pending|approved|rejected
fcmToken: string (optional)
createdAt: Timestamp
```

Edge Cases:

- Closing the app while `incomplete`: user returns directly to completion screen (guarded by routing in `main.dart`).
- Multiple social providers: `providers` is an array; subsequent social logins add provider via `FieldValue.arrayUnion`.
- Password signup uses status `pending` immediately (no incomplete stage).

## Firestore Composite Index (status + createdAt)

`VerificationScreen` queries pending accounts ordered by creation time. Firestore requires a composite index for `where status == 'pending' orderBy createdAt DESC`.

Index Definition:

- Collection: `Users`
- Fields:
  - `status` (Ascending)
  - `createdAt` (Descending)

### Firebase Console Steps

1. Open Firebase Console → Firestore Database → Indexes tab.
2. Click "Add Index" (Composite section).
3. Collection ID: `Users`.
4. Fields:
   - `status` → Ascending
   - `createdAt` → Descending
5. No additional filters needed.
6. Save; build takes ~minutes. UI will show state "Building" then "Ready".
7. Re-run the app; the query error (FAILED_PRECONDITION) disappears.

### CLI Alternative

Create a file `firestore.indexes.json` at the project root:

```
{
  "indexes": [
    {
      "collectionGroup": "Users",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    }
  ]
}
```

Deploy:

```
firebase deploy --only firestore:indexes
```

(Requires global install: `npm i -g firebase-tools` and project initialization.)

Verification:
Use Firebase Console → Firestore → Indexes to confirm entry is present and active.

## Manual Testing Checklist (User Flows)

### 1. Email Registration (Pending)

1. Register new student with Student ID.
2. Confirm `Users/{uid}` doc has `status: pending` and `role: student`.
3. Pending screen displays.
4. Approve from admin account; student gets routed to dashboard next session.

### 2. Social Sign-In → Incomplete → Completion → Pending

1. Sign in with Google (no prior account).
2. Check `Users/{uid}`: `status: incomplete`, `providers: [google]`, no `role` yet.
3. App routes to completion form.
4. Select role (student) + enter Student ID → submit.
5. Doc updates: now `role: student`, `status: pending`.
6. Approve; next navigation shows student dashboard.

### 3. Multi-Provider Linking

1. Sign in again using Facebook while still logged in.
2. `providers` array includes both `google` and `facebook`.

### 4. Approval / Rejection

1. Reject a pending user; ensure `status: rejected`.
2. App should show a rejection state or fallback (implement UI notice if not yet present).
3. Manually set back to `pending` (admin) → approve → dashboard access.

### 5. FCM Token Storage (If Enabled)

1. After sign-in, ensure token stored under `Users/{uid}.fcmToken`.
2. Approval trigger sends notification (if Cloud Function configured).

## Troubleshooting Index Issues

- Error: `FAILED_PRECONDITION: The query requires an index` → Build composite index as above.
- `createdAt` appears null: ensure you used `FieldValue.serverTimestamp()` and allow time for server write; avoid ordering by null values.
- Stale `status`: client may cache user doc; force refresh by reloading app or calling `_hydrateUser` on auth state change.

## FAQ Additions

**Why an 'incomplete' status?** Prevents granting privileges or dashboard access before the user picks an enforced role and (for students) supplies Student ID.

**Can users change role after approval?** Should be restricted; implement admin-only role changes in future with proper auditing.

**Why not rely solely on custom claims?** Claims require backend issuance; storing `status` in Firestore enables UI logic and manual moderation while claims secure privileged operations.

Token & Claim Security:

- Clients cannot self‑assign admin/approved status; Firestore rules should verify `request.auth.token.admin` for privileged paths.
- Custom claims are signed; tampering with local UI or stored fields cannot forge them.

## Firestore / Functions Samples

Sample Cloud Functions (see `cloud_functions_sample/index.js`):

- `promoteToAdmin` callable: only existing admin claim can assign new admin.
- `notifyApproval` trigger: detects `pending -> approved` and sends FCM.

Sample Rules (see `firestore.rules.sample`): restrict writes requiring admin.

## Push Notifications (FCM)

Flow:

1. App requests notification permission; retrieves FCM token.
2. Token stored in `Users/{uid}.fcmToken`.
3. Approval trigger uses this token to send notification.
4. Token refresh events update Firestore automatically.

Notes:

- For iOS add APNs setup (cert or key) in Firebase console.
- For Android 13+ request notification runtime permission.
- Avoid sending sensitive data in notification payloads.

## Troubleshooting QR & Location

- Camera permission denied: Grant in system settings and restart the app.
- QR not detected: Ensure sufficient lighting and that code uses standard encoding (UTF-8 text).
- Location null: Check permissions or toggle GPS; first fix may appear after a short delay due to reverse geocoding.

## Future Enhancements

- Teacher/Admin dashboards (session creation, reports)
- Attendance anomaly detection (late/early patterns)
- Push notifications (class reminders)
- Export attendance ranges to CSV

---

For contribution questions about auth or QR flow, open an issue referencing the relevant section above.

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
