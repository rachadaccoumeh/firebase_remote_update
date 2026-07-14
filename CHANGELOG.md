## 0.1.0

- Initial release.
- Force/optional update gate backed by Firebase Remote Config.
- Store-availability check: Play In-App Update (Android) and iTunes lookup (iOS).
- Fails-open design: any error results in no forced update.
- Emergency override flag to bypass the store check.
- `UpdateGate` widget for drop-in integration.
