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
