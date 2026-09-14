# Stay Composed — Flutter Frontend (Phase 1)

This is Phase 1 of the Stay Composed frontend: project setup, theme, routing,
authentication UI, the home dashboard, and every model/service interface the
rest of the app will build on. TrueOwner and Blood Donation feature screens
land in Phases 2 and 3.

## 1. Install Flutter

1. Download the Flutter SDK for your OS: https://docs.flutter.dev/get-started/install
2. Extract it somewhere permanent, e.g. `~/development/flutter`.
3. Add it to your PATH (macOS/Linux, add to `.zshrc`/`.bashrc`):
   ```
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```
4. Verify:
   ```
   flutter doctor
   ```
   Resolve any red ❌ items it reports (Android SDK, Xcode, etc).

## 2. Editor setup

Either works — install the **Flutter** and **Dart** extensions:
- **VS Code**: Extensions panel → search "Flutter" → install (Dart comes with it).
- **Android Studio**: Preferences → Plugins → search "Flutter" → install → restart.

## 3. Get the project running

From inside this folder:

```bash
flutter pub get
flutter run
```

`flutter run` will list connected devices/emulators/simulators if more than
one is available. To open an Android emulator: Android Studio → Device
Manager → start a virtual device, then re-run `flutter run`. For iOS, you
need a Mac with Xcode and can use `open -a Simulator`.

The app runs entirely on **mock data** right now — no backend, no real
Google OAuth client ID — so `flutter run` should work immediately after
`flutter pub get`.

## 4. What's implemented in Phase 1

- **State management: Riverpod** (`flutter_riverpod`). Chosen because:
  - It scales cleanly from a single `AuthController` today to the many
    independent-but-related controllers this app will need (lost reports,
    found reports, matches, verification, chat, blood requests) without a
    global store or heavy boilerplate.
  - Providers are easy to override in tests and easy to swap (mock service
    → real service) by changing one line, which matters a lot here since
    the backend is being built separately.
  - `StateNotifierProvider` gives explicit, typed states (`AuthStatus.authenticating`,
    `.error`, `.unauthorizedDomain`, etc.) which maps directly onto the
    loading/success/error/empty UI requirement in the spec.
- **Routing: go_router**, redirect-driven off auth state — unauthenticated
  users always land on `/login`, authenticated users skip it.
- **Theme**: Material 3, a dedicated indigo/teal/red palette (see
  `lib/core/theme/app_colors.dart`) so TrueOwner and Blood Donation stay
  visually distinct.
- **Auth UI**: splash → Google sign-in button → loading / error /
  unauthorized-college-domain states, all wired to a `MockAuthService`.
- **Home dashboard**: header (avatar, notifications, logout with
  confirmation dialog) + the two feature cards, nothing else — per the
  "no public feed" requirement.
- **All data models** (`lib/models/`) for both features, with lost/found
  object models deliberately splitting **public** fields from the
  **secret verification info** field so that boundary is enforced by the
  type system, not by screen-level discipline.
- **All service interfaces** (`lib/services/`) — `AuthService`,
  `TrueOwnerService`, `ChatService`, `BloodDonationService`,
  `ImageUploadService`, `AIService` — each documented with a
  `TODO: Connect backend API here` next to the parts a real API
  implementation needs to fill in.
- Placeholder (but real, navigable) TrueOwner and Blood Donation dashboard
  screens so the whole flow — login → home → into each feature — already
  works end to end.

## 5. Folder structure

```
lib/
├── core/
│   ├── constants/     # app_constants.dart — college domains, config defaults
│   ├── theme/         # colors, text styles, ThemeData
│   ├── routes/        # route constants + GoRouter setup
│   ├── utils/         # ApiResult (loading/success/error wrapper)
│   └── widgets/       # PrimaryButton, StatusBadge, empty/error/loading views
├── features/
│   ├── authentication/  # splash, login, auth provider
│   ├── home/             # dashboard screen + feature card widget
│   ├── true_owner/       # dashboard placeholder (Phase 2 fills this out)
│   └── blood_donation/   # dashboard placeholder (Phase 3 fills this out)
├── models/             # AppUser, LostObject, FoundObject, MatchResult,
│                        # VerificationRequest, Claim, Chat, BloodRequest, etc.
├── services/           # abstractions only — mock implementations arrive
│                        # in Phase 2/3 alongside the screens that use them
└── main.dart
```

## 6. Connecting your real backend later

Every place that needs a real API call is marked `TODO: Connect backend API
here`. The pattern throughout is: **screens never call `dio`/HTTP directly**
— they only depend on the abstract service interfaces in `lib/services/`.
To go live, you write one new class per interface (e.g. `ApiAuthService
implements AuthService`) and swap the single `Provider` that constructs it
(e.g. `authServiceProvider` in `auth_provider.dart`). No screen code changes.

## 7. What's next

- **Phase 2** — TrueOwner: Report Lost / Report Found forms (with the
  secret-verification-info UI treatment), AI-matching state, match result
  cards, owner↔finder connection, two-sided verification flow, private
  chat, claim success, My Lost/Found Objects.
- **Phase 3** — Blood Donation: request form, request detail, send-to-departments
  flow, request history.
- **Phase 4** — Profile, notifications, polish pass (animations, empty/error
  states everywhere, responsive QA on tablet sizes).
