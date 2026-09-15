# TrueOwner module — v2, verified against your actual FastAPI source

Unzip over your existing `lib/`. This replaces the previous drop — v1 was built from a
routes doc + a Copilot paraphrase and got several things wrong that I've now corrected
against `app/models.py`, `app/routers/items.py`, `app/routers/chat.py`,
`app/routers/claims.py`, `app/security.py`, `app/config.py`, `app/utils/locations.py`.

## What actually changed since v1 (read this first)

1. **Canned prompts were wrong strings.** `app/routers/chat.py` checks pre-verification
   messages for *exact* equality against a 4-string `PRE_VERIFICATION_MESSAGES` set. My v1
   placeholder list had 8 different phrases — every one of them would have come back
   rejected. Now byte-for-byte identical to the backend's whitelist:
   - `Where exactly did you find it?`
   - `Can you describe the item?`
   - `What time did you find it?`
   - `Can you share a safe public meeting point?`

2. **Location is a fixed 9-item dropdown, not free text.** `app/utils/locations.py` has a
   `CAMPUS_LOCATIONS` list; the backend rejects anything not in it for "found" reports, and
   scores an 8-point match bonus on exact string equality — free text would silently break
   matching even where it didn't get rejected outright. New file
   `lib/core/constants/campus_locations.dart` mirrors that list exactly. Location is
   compulsory for "found", optional for "lost"; "Others" needs a detail field only for found.

3. **Found reports need a photo AND paired question+answer, not just questions.**
   `ItemCreate` has a separate `secretAnswers: list[str]` field, index-aligned with
   `challengeQuestions` — I only had `challengeQuestions` before. The backend rejects a
   found report with an empty/mismatched-length pair, or no image. `report_item_screen.dart`
   now renders each challenge as a question+hidden-answer pair, validates both required,
   and sends `secretAnswers` in the create body. `Item` gained a write-only `secretAnswers`
   field for this.

4. **The WebSocket frame shapes were guessed wrong.** Real frames from
   `app/routers/chat.py`:
   - New message: `{"type": "message", "id", "threadId", "senderEmail", "text", "sentAt"}`
   - Rejected message: `{"type": "error", "message", "allowedMessages"?}`
   - Phase change: `{"event": "phase_changed", "status": "verification_pending" | "verified" | "handed_over"}`

   My v1 `_handleFrame` checked for a `text` key directly and an `error`/`detail` key — it
   would have silently dropped every error frame and every phase-change event.
   `chat_socket_service.dart` is rewritten to parse these correctly, and now exposes a
   `phaseChanges` stream so `ChatScreen` reacts to `start-verification`/`complete-handover`
   *instantly* instead of only finding out on the next 20s poll (poll kept as a fallback for
   a dropped socket, interval relaxed from 10s to 20s since it's no longer the primary path).

5. **Error messages were being swallowed app-wide, not just true-owner.** FastAPI's
   `HTTPException(detail=...)` is what every route in your backend actually raises. The
   shared `ApiClient._decode()` only read `message`/`error` keys — none of your 400/403/409
   error text (confidence threshold, "founder hasn't started verification yet", "no
   verification challenge configured") ever reached the user. **This is the one edit outside
   `features/true_owner/` and the true-owner models/services** — a single additive
   `detail` check in `lib/core/network/api_client.dart`. It changes nothing for responses
   that don't use `detail`, so blood-alert is unaffected either way, but is now correctly
   fixed for every module going forward.

6. **The claim screen's fallback questions were wrong.** v1 guessed that if a found item had
   no `challengeQuestions`, the owner could answer using their own `secretFeatures` instead.
   Your actual `app/routers/claims.py` has no such fallback — `secretFeatures` (on the lost
   item) and the found item's answers are unrelated fields, and a found item created through
   this app always has at least one challenge question (creation is rejected otherwise). If
   an empty list is ever encountered (legacy data only), the backend 400s with "no
   verification challenge configured" — so `ClaimScreen` now shows that state directly
   instead of rendering a form that can never succeed.

## New files
```
lib/models/item_model.dart            Item, CandidateMatch, MyItems
lib/models/chat_thread_model.dart     ChatThread, ChatMessage, ChatPhase
lib/models/claim_model.dart           ClaimResult
lib/services/chat_socket_service.dart WebSocket /chat/ws/{thread_id}
lib/core/constants/campus_locations.dart  Fixed location dropdown, synced with backend
lib/features/true_owner/providers/true_owner_providers.dart
lib/features/true_owner/widgets/true_owner_widgets.dart
lib/features/true_owner/screens/report_item_screen.dart
lib/features/true_owner/screens/item_detail_screen.dart
lib/features/true_owner/screens/chat_screen.dart
lib/features/true_owner/screens/claim_screen.dart
```

## Replaced files
```
lib/services/true_owner_service.dart                              stub -> real REST impl
lib/features/true_owner/screens/true_owner_dashboard_screen.dart   placeholder -> Lost/Found/Chats tabs
lib/core/routes/app_routes.dart                                   true-owner paths updated
lib/core/routes/app_router.dart                                   true-owner routes wired
lib/core/network/api_client.dart                                  +1 line: read 'detail' key (see #5 above)
```

## pubspec.yaml — two additions needed
```yaml
dependencies:
  web_socket_channel: ^3.0.1
  image_picker: ^1.1.2
```

## Confirmed-correct backend behaviors now reflected in the app
- `POST /claims`: `answers[i]` matched positionally against the found item's stored hash at
  index `i` — bcrypt exact/normalized match first, then CLIP semantic similarity (≥0.68
  cosine) as a fallback. `verified = matched > total/2`.
- If a chat thread exists for a pair, `/claims` requires it to be in `verifying` status —
  the founder must call `start-verification` first. Pairs that never crossed the
  `chat_min_confidence` gate (no thread) can be claimed directly; the app only ever opens
  `ClaimScreen` from the chat's "Answer" button, so this always matches the gated path.
- `chatConfidenceThreshold` in `/items/mine` is real (`settings.chat_min_confidence`,
  default 50) and `POST /chat/thread` actually enforces it server-side with a 403 whose
  `detail` is `"AI match confidence ({n}) hasn't reached the chat threshold ({t}) yet."` —
  now correctly surfaced end-to-end.
- Claim cooldown: 5 attempts per found item per 30 minutes, then `verified: false` with a
  `cooldownUntil` — already handled by `ClaimResult.isOnCooldown` in the claim screen.
- `reportedBy` is masked server-side as `"Campus Member <FirstName>"` — displayed as-is,
  no assumptions made about its format.

## Route -> screen map (unchanged from v1)
| Route | Screen |
|---|---|
| `POST /items` | `ReportItemScreen` |
| `GET /items/mine` | `TrueOwnerDashboardScreen` + `ItemDetailScreen` |
| `POST /chat/thread` | "Chat with finder" on `MatchCard` |
| `GET /chat/my-threads` | Chats tab, 20s fallback poll |
| `GET /chat/{id}/messages` | `ChatScreen` history load |
| `WS /chat/ws/{id}` | `ChatSocketService` — messages + errors + phase events |
| `POST /claims` | `ClaimScreen` |
| `POST /chat/{id}/complete-handover` | `ChatScreen` app-bar action |

## Still worth double-checking against your source before shipping
- `category` has no server-side enum — the app still uses its own free-pick list in
  `AppConstants.lostFoundCategories`. If you want categories to also score a match bonus
  reliably, consider constraining that list the same way `CampusLocations` is now.
- The claim screen's positional `answers[i]` assumes the questions render in the exact order
  `challengeQuestions` was stored in — confirmed correct, no reordering happens anywhere in
  the app.
