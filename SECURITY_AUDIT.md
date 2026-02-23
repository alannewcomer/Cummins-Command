# Security Audit Report — Cummins Command V2

**Date:** 2026-02-23
**Scope:** Full codebase security review (Flutter/Dart client, Firebase rules, Cloud Functions, Android config)

---

## Executive Summary

The Cummins Command codebase has a **solid security foundation** with properly scoped Firestore rules, good .gitignore hygiene, and no critical vulnerabilities. The audit identified **3 medium-severity** and **5 low-severity** findings, primarily around Firebase App Check enforcement, Firestore rules gaps for the sharing feature, and minor hardening opportunities.

**No critical vulnerabilities found.**

---

## Findings

### MEDIUM Severity

#### M1. Firebase App Check Not Activated

**Location:** `lib/main.dart`, `pubspec.yaml`
**Description:** The `firebase_app_check` package is listed as a dependency but is never initialized in the app. App Check verifies that requests to Firebase backends come from your legitimate app, blocking abuse from spoofed clients or scripts using your public API keys.

**Risk:** Without App Check, anyone with the public Firebase API keys (visible in `firebase_options.dart`) can call your Firestore/Storage APIs directly, potentially abusing quota or scraping data within the scope allowed by security rules.

**Recommendation:**
```dart
// In main.dart, after Firebase.initializeApp():
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  webProvider: ReCaptchaEnterpriseProvider('your-site-key'),
);
```
Also enforce App Check in Cloud Functions and Firebase Console.

---

#### M2. `shareInvites` Collection Missing Firestore Rules

**Location:** `firestore.rules`, `lib/services/share_service.dart`
**Description:** The client-side `ShareService` reads and writes to a top-level `shareInvites` collection (lines 67, 108, 135, 214, 349). However, the Firestore rules have no match for `shareInvites` — it falls through to the catch-all deny rule:
```
match /{document=**} {
  allow read, write: if false;
}
```

This means the sharing feature's client-side operations on `shareInvites` will be **blocked by Firestore rules**. The Cloud Function `processVehicleShare` writes to a different collection (`invites`), which does have rules.

**Risk:** The sharing-by-code feature is non-functional from the client side. If rules are loosened to fix this without proper scoping, it could create an authorization bypass.

**Recommendation:** Add scoped rules for `shareInvites`:
```javascript
match /shareInvites/{code} {
  // Only authenticated users can create (the client writes invite docs)
  allow create: if request.auth != null;
  // Read access for authenticated users (code-based lookup)
  allow read: if request.auth != null;
  // Only the owner or the system should delete (after acceptance)
  allow delete: if request.auth != null && (
    resource.data.ownerUserId == request.auth.uid
  );
  // No client updates — only Cloud Functions should modify
  allow update: if false;
}
```

---

#### M3. Cloud Functions — `checkPredictiveMaintenance` Iterates All Users Without Pagination

**Location:** `functions/index.js:233`
**Description:** The daily scheduled function `checkPredictiveMaintenance` calls `db.collection(USERS).get()` which loads **all user documents** into memory at once. Similarly, `computeBaseline` (line 301) does the same.

**Risk:** As the user base grows, this will hit Cloud Functions memory limits, cause timeouts, and potentially expose the function to denial-of-service via large dataset processing. It also makes one Gemini API call per vehicle per user — no rate limiting.

**Recommendation:**
- Use paginated queries with `limit()` and `startAfter()` cursors
- Add rate limiting for Gemini API calls
- Consider using Cloud Tasks for fan-out to individual user processing

---

### LOW Severity

#### L1. Firebase API Keys in Source Control (Expected but Document)

**Location:** `lib/firebase_options.dart:53-67`
**Description:** Firebase Web and Android API keys are committed to source. This is the **standard Flutter/Firebase pattern** — these keys are designed to be public and are restricted by Firebase Security Rules and App Check (see M1).

**Risk:** Low with proper security rules (which are in place). Risk elevates to medium if App Check is not enabled, as anyone can use these keys to authenticate and interact with your backend.

**Recommendation:** No change needed for the keys themselves. Ensure App Check (M1) is enabled to restrict usage to legitimate app instances.

---

#### L2. Google OAuth Web Client ID Hardcoded

**Location:** `lib/providers/auth_provider.dart:17-18`
**Description:** The Google OAuth web client ID is hardcoded. This is a public identifier (not a secret) required by the Google Sign-In SDK.

**Risk:** Minimal — OAuth client IDs are designed to be public. The security comes from redirect URI validation configured in Google Cloud Console.

**Recommendation:** No immediate action needed. Verify that authorized redirect URIs in Google Cloud Console are restricted to your domains only.

---

#### L3. Export Download URLs Valid for 7 Days

**Location:** `functions/index.js:536-538`
**Description:** The `exportDriveData` function generates signed URLs with a 7-day expiry. These URLs are stored in Firestore job documents accessible to the user.

**Risk:** If a signed URL is leaked (e.g., via shared screen, logs), the drive data is accessible to anyone with the URL for up to 7 days.

**Recommendation:** Consider reducing expiry to 1 hour or implementing on-demand URL generation where the user requests a fresh URL when ready to download.

---

#### L4. Web `index.html` Missing Security Headers

**Location:** `web/index.html`
**Description:** The web entry point lacks Content Security Policy (CSP) meta tags. While Firebase Hosting can add these via `firebase.json` headers config, they're not present.

**Recommendation:** Add CSP headers in `firebase.json` hosting config:
```json
{
  "hosting": {
    "headers": [{
      "source": "**",
      "headers": [{
        "key": "Content-Security-Policy",
        "value": "default-src 'self'; script-src 'self' https://apis.google.com; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com"
      }]
    }]
  }
}
```

---

#### L5. Debug Logging May Contain Sensitive Context

**Location:** `lib/services/diagnostic_service.dart`, `lib/features/ai_insights/ai_insights_screen.dart:58`
**Description:** The `DiagnosticService` uploads log batches to Firestore (`users/{uid}/devLogs`). While logs are scoped to the user's own data, Bluetooth MAC addresses and connection details are logged and uploaded.

**Risk:** Bluetooth MAC addresses are considered personal identifiers under GDPR. The diagnostic logs also persist connection attempt details that could be useful in a forensic attack.

**Recommendation:**
- Sanitize MAC addresses in logs before Firestore upload (e.g., partial masking)
- Add a user-visible toggle for remote diagnostic logging
- Consider auto-expiring devLogs documents (TTL policy in Firestore)

---

## Positive Findings (What's Done Well)

| Area | Assessment |
|------|-----------|
| **Firestore Rules** | Owner-scoped rules with `request.auth.uid == userId` checks on all user data paths. Catch-all deny rule blocks unmatched paths. |
| **Storage Rules** | Properly scoped to `request.auth.uid == userId` for drive data. |
| **No Cleartext HTTP** | Zero `http://` URLs found in Dart source. All network communication uses HTTPS. |
| **No SSL Bypass** | No `badCertificateCallback` overrides or certificate pinning bypasses found. |
| **No Command Injection** | No `Process.run` or `Process.start` usage in client code. |
| **No WebView** | No WebView components that could introduce XSS attack surface. |
| **Keystore Handling** | Android signing uses `key.properties` (gitignored) — no hardcoded keystore passwords. |
| **ProGuard Enabled** | Release builds use R8/ProGuard with minification and resource shrinking. |
| **.gitignore** | Comprehensive — excludes `google-services.json`, `.env`, `.jks`, `.keystore`, `key.properties`, `functions/.env`. |
| **Cloud Functions Secrets** | `functions/` uses `process.env.GEMINI_API_KEY` — not hardcoded. |
| **Input Validation** | VIN field has length/character validation. Form fields use Flutter validators. |
| **Secure Random** | Share codes generated with `Random.secure()` — cryptographically secure. |
| **Invite Expiry** | Share invites have configurable expiry (default 7 days) with server-side validation. |
| **Null Safety** | Full Dart null safety enabled (SDK ^3.9.0). |
| **Android Permissions** | Bluetooth permissions use `neverForLocation` flag where appropriate. Permissions are properly declared. |
| **No Sensitive Logging** | No passwords, tokens, or auth credentials appear in log statements. |

---

## Dependency Review

### Flutter/Dart (`pubspec.yaml`)
All dependencies are well-known, actively maintained packages from pub.dev:
- **firebase_*** — Official Google Firebase packages
- **flutter_riverpod** — State management (no security concerns)
- **go_router** — Navigation (no security concerns)
- **flutter_bluetooth_classic_serial** — Bluetooth Classic (inherent BT security applies)
- **shared_preferences** — Stores only non-sensitive data (adapter MAC address)

No known CVEs identified for the listed dependencies at current versions.

### Cloud Functions (`functions/package.json`)
- `firebase-functions: ^7.0.0` — Current
- `firebase-admin: ^12.0.0` — Current
- `@google/genai: ^1.0.0` — Current

**Note:** `flutter` CLI was not available in this environment, so `flutter pub outdated` could not be run. Consider running it locally to check for available updates.

---

## Summary Table

| ID | Severity | Finding | Status |
|----|----------|---------|--------|
| M1 | Medium | Firebase App Check not activated | Open |
| M2 | Medium | `shareInvites` collection missing Firestore rules | Open |
| M3 | Medium | Scheduled functions iterate all users without pagination | Open |
| L1 | Low | Firebase API keys in source (expected pattern) | Acknowledged |
| L2 | Low | OAuth client ID hardcoded (expected pattern) | Acknowledged |
| L3 | Low | Export download URLs valid for 7 days | Open |
| L4 | Low | Web CSP headers not configured | Open |
| L5 | Low | Debug logs may contain BT MAC addresses | Open |

**Total: 0 Critical, 0 High, 3 Medium, 5 Low**
