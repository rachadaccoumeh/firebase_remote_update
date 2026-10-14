## 0.3.1

Faster update rollout: a forced update no longer waits up to 1 hour.

- **New** `UpdateGate` options (all off by default, so 0.3.0 behavior stays):
  - `recheckInterval` — re-check while the app stays open.
  - `resumeRecheckAfter` — re-check when the app returns to the foreground
    and the last check is older than this (needs `app_update_gate` 0.1.2).
  - `listenForRealtimeUpdates` — re-check as soon as a Remote Config change
    is published (Firebase real-time Remote Config; no console setup).
- **New** `AppUpdateService.configUpdates()`: activated real-time updates as
  a stream. Errors are logged and dropped (fail open).
- Requires `app_update_gate: ^0.1.2`.
- Custom classes that `implements AppUpdateService` (test fakes) must add
  `configUpdates()`.

## 0.3.0

**Rebuilt as a thin adapter over `app_update_gate`** — the source-agnostic
core extracted from this package. The public API (`AppUpdateConfig`,
`AppUpdateService`, `UpdateGate`, `RemoteConfigKeys`) is unchanged; this
package now only supplies the Firebase Remote Config policy source
(`FirebaseRemoteConfigPolicySource`).

- **New**: the core's types are re-exported — `AppUpdateController`
  (observable status, periodic re-checks, manual checks),
  `ForcePresentation.onNextNavigation` + `UpdateGateNavigatorObserver`,
  `UpdatePolicySource`/`HttpUpdatePolicySource`, and `VersionScheme`.
- **Breaking (edge cases only)**:
  - Custom `StoreAvailabilityChecker` implementations: `check` now takes
    named parameters `({AppVersion? minRequired, AppVersion? currentVersion})`.
  - A bare integer in a Remote Config version value (e.g. `"2"`) is now
    rejected and fails open; use a dotted version (`"2.0.0"`). This prevents
    build codes from being misread as huge semantic versions.

## 0.2.1

- **Fix**: `AppVersion.tryParse` now finds the dotted version anywhere in the
  string and ignores decorations around it: `1.4.9 (149)`, `149 1.4.9`,
  `v1.4.9`, `release 1.4.9 build 149`, `1.4.9-beta` all parse as `1.4.9`. The
  App Store lookup API returns the hand-written marketing version verbatim;
  when a developer typed the build number into it, the old parser returned
  `null`, the store gate failed open, and **forced updates silently stopped on
  iOS**. The same applied to Remote Config values with a suffix.
- **Safety**: a string with two or more dotted versions (ambiguous) or with no
  parseable version still returns `null`, so callers keep failing open and a
  bad string can never force or lock users.

## 0.2.0

- **New**: `UpdateGateMode` enum with `nonBlocking` (default) and `blocking` modes.
- **Breaking**: `UpdateGate` now defaults to `UpdateGateMode.nonBlocking` — the app
  renders immediately and the update policy is evaluated in the background. If the
  result is forced, the gate swaps to `forcedBuilder` after evaluation completes.
- To keep the old behavior (hide the app until the decision is resolved), pass
  `mode: UpdateGateMode.blocking`.
- `loadingBuilder` is now only used in `blocking` mode. In `nonBlocking` mode it is
  ignored.
- Optional updates and `onDecision` behavior are unchanged.

## 0.1.0

- Initial release.
- Force/optional update gate backed by Firebase Remote Config.
- Store-availability check: Play In-App Update (Android) and iTunes lookup (iOS).
- Fails-open design: any error results in no forced update.
- Emergency override flag to bypass the store check.
- `UpdateGate` widget for drop-in integration.
