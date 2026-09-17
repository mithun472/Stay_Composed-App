<div align="center">

<img src="stay_composed.png" alt="Stay Composed" width="500" height="500"/>

# 🌟 Stay Composed — Mobile App

### *Flutter client for Campus Lost & Found + Emergency Blood Alerts*

[![Flutter](https://img.shields.io/badge/Flutter-3.3+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.3-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Riverpod](https://img.shields.io/badge/State-Riverpod_2.5-4B32C3?style=for-the-badge&logo=flutter&logoColor=white)](https://riverpod.dev/)
[![go_router](https://img.shields.io/badge/Routing-go__router_14-00B4AB?style=for-the-badge&logo=flutter&logoColor=white)](https://pub.dev/packages/go_router)
[![Firebase](https://img.shields.io/badge/Push-Firebase_FCM-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)
[![WebSocket](https://img.shields.io/badge/Realtime-WebSockets-010101?style=for-the-badge&logo=socket.io&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
[![Cloudinary](https://img.shields.io/badge/Storage-Cloudinary_CDN-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white)](https://cloudinary.com/)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Android APK](https://img.shields.io/badge/Download_APK-Android_v1.0.0-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/<your-username>/<your-repo>/releases/download/v1.0.0/StayComposed-v1.0.apk)

**Campus help reaching the right person, fast — without panic or vulnerability.**

[✨ Features](#-key-features) • [🏗️ Architecture](#️-architecture) • [🎨 Design System](#-design-system) • [🚀 Quick Start](#-getting-started) • [🔌 API Surface](#-api-surface) • [📁 Structure](#-project-structure)

</div>

---

## 📌 Overview

**Stay Composed** is the Flutter front end of the TrueOwner campus platform. It talks to a FastAPI + MongoDB backend that runs CLIP multimodal matching, bcrypt-hashed ownership challenges, and SMTP blood-alert broadcasts.

| | |
| --- | --- |
| **Package** | `stay_composed` · `v0.1.0+1` |
| **SDK** | Dart `>=3.3.0 <4.0.0` |
| **State** | `flutter_riverpod` (`ProviderScope` at root) |
| **Routing** | `go_router` — declarative, auth-redirect aware |
| **Transport** | `dio` (REST) + `web_socket_channel` (live chat) |
| **Auth** | `google_sign_in` — backend verifies the domain and the token |
| **Backend URL** | Runtime-configurable in Settings, persisted in `SharedPreferences` |

> [!NOTE]
> The base URL is **not** compiled in. Point the app at any backend (localhost, LAN, ngrok tunnel) from the Settings screen — no rebuild, no reinstall.

---

## ✨ Key Features

### 🔍 1. TrueOwner — Lost & Found

- **Report Lost / Report Found** flows with photo capture (`image_picker`) and direct Cloudinary unsigned upload.
- **Zero public browsing.** Found items never render in a public list; they surface only against a matching lost report.
- **Match confidence UI** — candidate cards rendered from backend cosine-similarity scores.
- **Fixed campus location dropdown**, kept byte-for-byte in sync with the backend's `locations.py` because match scoring compares location strings exactly.

### 🛡️ 2. Ownership Challenge Screen

- Finder sets 1–3 secret questions at report time; answers leave the device already destined for bcrypt hashing.
- Claimant answers inside `claim_screen.dart`; server does exact match first, semantic fallback second.
- Attempt counter and lockout state surfaced through `StatusBadge` + `api_result.dart` error mapping.

### 💬 3. Real-Time Handover Chat

- `chat_socket_service.dart` opens `wss://<host>/chat/ws/{thread_id}?email=`.
- **Scheme auto-swap**: `https → wss`, `http → ws`. Swapping tunnels needs no code change.
- **Presence heartbeat** so a half-dead backgrounded socket does not leave a user falsely "online".
- Never throws — every failure path (missing URL, refused connect, stale tunnel) degrades to an offline state instead of crashing the screen.
- One-tap campus meeting-point chips.

### 🩸 4. Emergency Blood Alert

- `blood_alert_form_screen.dart` → `POST /blood-alert` → backend fans out over SMTP to staff and student directories.
- `my_blood_alerts_screen.dart` tracks alerts the user raised.
- All 8 blood groups, dedicated red accent so the module is never confused with TrueOwner at a glance.

### 🔔 5. Push Notifications (FCM)

- Top-level `@pragma('vm:entry-point')` background handler — registered as an instance method it silently no-ops, so it lives outside the class on purpose.
- Token registration deferred to `addPostFrameCallback` so the signed-in email is attached to `/devices/register`.
- Foreground banners via `flutter_local_notifications`; tap-to-route through `onMessageOpenedApp` / `getInitialMessage`.

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     Flutter Client                       │
│                                                          │
│   features/         core/              services/         │
│   ├─ authentication ├─ routes          ├─ auth           │
│   ├─ true_owner     ├─ theme           ├─ google_auth    │
│   ├─ blood_donation ├─ network         ├─ true_owner     │
│   ├─ notifications  ├─ config          ├─ blood_alert    │
│   ├─ profile        ├─ constants       ├─ chat_socket    │
│   ├─ settings       ├─ widgets         ├─ cloudinary     │
│   └─ home           └─ utils           └─ push_notif     │
└───────────────┬──────────────────────────┬───────────────┘
                │ dio / REST               │ WebSocket
                ▼                          ▼
        ┌───────────────────────────────────────────┐
        │        FastAPI backend (Python)           │
        │  CLIP embeddings · bcrypt · SMTP · FCM    │
        └──────────────┬─────────────┬──────────────┘
                       ▼             ▼
               MongoDB Atlas    Cloudinary CDN
```

**Layering rule:** screens never call `dio` directly. Screens → Riverpod providers → services → `api_client.dart`. Every service returns `ApiResult<T>`, so error handling is one `switch` at the widget layer instead of scattered `try/catch`.

---

## 🎨 Design System

Calm, institutional "campus security" feel — not a playful consumer palette.

| Token | Hex | Usage |
| --- | --- | --- |
| **Deep Indigo** | `#2D3A8C` | Brand anchor, primary buttons, app bars |
| **Indigo Dark** | `#1E2762` | Pressed states, gradient ends |
| **Teal** | `#0F9B8E` | TrueOwner accent, verification actions |
| **Deep Red** | `#C62828` | Blood Donation only — never for TrueOwner |
| **Canvas** | `#F7F8FC` | App background |
| **Surface** | `#FFFFFF` | Cards, sheets, dialogs |
| **Ink** | `#1A1C2E` | Primary text |
| **Slate** | `#5C5F72` | Secondary text, expired states |
| **Success** | `#1E8E3E` | Verified, resolved |
| **Warning** | `#B07A00` | Pending verification |

> [!TIP]
> Blood red is reserved. Keeping TrueOwner on teal and Blood on red means a user knows which module they are in from a single glance at the accent color.

---

## 📁 Project Structure

```
lib/
├── main.dart                          # Bootstrap: dotenv → Firebase → ProviderScope
│
├── core/
│   ├── config/backend_config.dart     # Runtime base URL + Riverpod notifier
│   ├── constants/
│   │   ├── app_constants.dart         # App name, blood groups, categories, domains
│   │   └── campus_locations.dart      # Fixed dropdown — mirrors backend locations.py
│   ├── network/api_client.dart        # dio wrapper, headers, error normalization
│   ├── routes/
│   │   ├── app_router.dart            # go_router config + auth redirects
│   │   └── app_routes.dart            # Path constants — never hardcode strings
│   ├── theme/                         # app_colors · app_text_styles · app_theme
│   ├── utils/api_result.dart          # Success / Failure union type
│   └── widgets/                       # primary_button · status_badge · placeholders
│
├── models/                            # 13 immutable models (equatable)
│   ├── item_model.dart                ├── blood_request_model.dart
│   ├── lost_object_model.dart         ├── blood_alert_model.dart
│   ├── found_object_model.dart        ├── chat_thread_model.dart
│   ├── match_result_model.dart        ├── chat_model.dart
│   ├── claim_model.dart               ├── notification_model.dart
│   ├── verification_model.dart        ├── user_model.dart
│   └── enums.dart
│
├── services/
│   ├── auth_service.dart              ├── chat_socket_service.dart
│   ├── google_auth_service.dart       ├── cloudinary_service.dart
│   ├── true_owner_service.dart        ├── push_notification_service.dart
│   ├── blood_alert_service.dart       └── other_services.dart
│
└── features/
    ├── authentication/                # splash · login · auth_provider
    ├── home/                          # home_screen · feature_card
    ├── true_owner/                    # dashboard · report · detail · claim · chat
    ├── blood_donation/                # dashboard · alert form · my alerts
    ├── notifications/                 # screen + provider
    ├── profile/                       # history, resolved reports
    └── settings/                      # backend URL, preferences

assets/images/stay_composed_logo.png   # Also the launcher icon source
```

---

## 🔌 API Surface

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/items` | Register a lost or found report |
| `GET` | `/items` | Candidate matches for the caller |
| `GET` | `/items/mine` | Caller's own reports |
| `POST` | `/claims` | Submit ownership challenge answers |
| `GET` | `/chat/my-threads` | Active handover threads |
| `GET` | `/chat/thread` | Message history for one thread |
| `WS` | `/chat/ws/{thread_id}?email=` | Live chat + presence |
| `POST` | `/blood-alert` | Broadcast an emergency blood request |
| `GET` | `/blood-alert/mine` | Alerts raised by the caller |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter** `3.19+` (Dart `3.3+`) — `flutter doctor` clean
- **Android Studio** / Xcode toolchain
- A running **Stay Composed FastAPI backend** (reachable from the device)
- **Firebase project** with an Android app registered
- **Cloudinary** cloud name + unsigned upload preset

### 1️⃣ Install

```bash
git clone <this-repo>
cd stay_composed
flutter pub get
```

### 2️⃣ Environment

```bash
cp .env.example .env
```

```env
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_UPLOAD_PRESET=your-unsigned-preset
```

> [!WARNING]
> Public values only. `GOOGLE_CLIENT_SECRET`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, and `NEXTAUTH_SECRET` stay in the **backend** `.env`. Anything in this file ships inside the APK and is readable by anyone who unzips it.

### 3️⃣ Firebase

Drop `google-services.json` into `android/app/`. Register the SHA-1 for Google Sign-In:

```bash
cd android && ./gradlew signingReport
```

### 4️⃣ Launcher icon

```bash
flutter pub run flutter_launcher_icons
```

### 5️⃣ Run

```bash
flutter run
# release APK
flutter build apk --release
```

### 6️⃣ Point at the backend

Open the app → **Settings** → paste the base URL (e.g. `https://abcd-1234.ngrok-free.app`) → save. Persisted across restarts; trailing slashes are stripped automatically.

---

## 🔐 Security Notes

> [!IMPORTANT]
> - **No secrets in the client.** `.env` carries public Cloudinary values only; the backend holds every credential.
> - **Domain-locked sign-in.** Only verified institutional accounts (`tcarts.in`) onboard — enforced server-side, not just in the UI.
> - **Answers never leave in plaintext storage.** Challenge answers are bcrypt-hashed on the backend; the client keeps no copy.
> - **`SharedPreferences` is a cache, not a source of truth.** Session data only; the server re-validates every request.
> - **Policy lives on the server.** Attempt limits, chat expiry, and unclaimed timeouts in `AppConfig` are frontend defaults meant to be overridden by API values.

---

## 🗺️ Roadmap

- [ ] Replace `AppConfig` constants with a remote-config endpoint
- [ ] Fetch allowed email domains from the server instead of a hardcoded list
- [ ] Offline queue for reports filed without connectivity
- [ ] Dark theme tokens (`AppColors` is already token-based)
- [ ] iOS release build + APNs wiring
- [ ] Widget and integration test coverage

---

<div align="center">

**Built with ❤️ for campus safety and student support.**

Thanks to the open-source work behind **Flutter**, **Riverpod**, **OpenAI CLIP**, **FastAPI**, and **Firebase**.

*Stay Composed • TrueOwner Verification System • 2026*

</div>
