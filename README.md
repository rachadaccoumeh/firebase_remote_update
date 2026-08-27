# firebase_remote_update

A small, reusable force/optional update gate for Flutter apps.

- **Policy source:** Firebase Remote Config (per-platform min & recommended versions, a global kill switch, an emergency override, and an optional message).
- **Safety gate:** before forcing, it verifies the target build is actually available on the store — Play In-App Update on Android, iTunes lookup on iOS — so users are never locked out of a build that isn't live yet.
- **Fails open:** any error (no network, bad config, throttled fetch) results in *no* forced update.
- **Built on [`app_update_gate`](https://pub.dev/packages/app_update_gate):** since 0.3.0 this package is a thin adapter that adds the Firebase Remote Config policy source on top of the source-agnostic core. The core's extras (observable status, periodic re-checks, navigation-deferred forced screens, HTTP/API policy sources) are re-exported and available from this same import.

## Why

The classic force-update bug is flipping the minimum version before the matching build is approved/rolled out, which locks users out with no installable update. This module gates the force on real store availability to prevent that, while still allowing a deliberate emergency lockout.

## Usage

```dart
import 'package:firebase_remote_update/firebase_remote_update.dart';

const config = AppUpdateConfig(
  androidPackageId: 'com.xxx.xxxxxxx',
  iosAppStoreId: 'xxxxxxxxxxx',
  storeCountry: 'xx',
);

final service = AppUpdateService(config: config); // uses FirebaseRemoteConfig.instance

// Wrap your app (non-blocking — app renders immediately, evaluation runs in
// the background):
UpdateGate(
  service: service,
  forcedBuilder: (context, decision) => MyUpdateScreen(service: service, decision: decision),
  child: myHome,
);

// Or use blocking mode (app hidden behind a loading screen until the decision
// is resolved):
UpdateGate(
  service: service,
  mode: UpdateGateMode.blocking,
  loadingBuilder: (context) => MyLoadingScreen(),
  forcedBuilder: (context, decision) => MyUpdateScreen(service: service, decision: decision),
  child: myHome,
);
```

Call `service.startUpdate()` from the update screen's button.

### Modes

| Mode | Behavior | When to use |
| --- | --- | --- |
| `nonBlocking` (default) | App renders immediately. If the result is forced, the gate swaps to `forcedBuilder` after evaluation. | Most apps — fastest perceived startup. |
| `blocking` | App is hidden behind `loadingBuilder` until the decision is resolved. | When you need the decision before any UI is visible (e.g. to avoid a flash of the main screen before a forced update). |

## Remote Config parameters

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `force_update_enabled` | bool | `false` | Global kill switch for forced updates. |
| `min_required_version_android` / `_ios` | string | `0.0.0` | Force below this version. |
| `recommended_version_android` / `_ios` | string | `0.0.0` | Soft prompt below this version. |
| `force_ignore_store_check` | bool | `false` | Emergency: force even if the build isn't on the store yet. |
| `update_message` | string | `''` | Optional message shown on the update screen. |

Parameter names are configurable via `RemoteConfigKeys`.

## Version string parsing

The iOS store check reads the `version` field from the public iTunes lookup
API (`https://itunes.apple.com/lookup?id=<appStoreId>&country=<cc>`). That
field is the **hand-written marketing version** from App Store Connect — not
the build number, which the public API does not expose.

Since 0.2.1 the parser is tolerant: it finds the dotted version anywhere in
the string and ignores the text around it. `1.4.9 (149)`, `149 1.4.9`,
`v1.4.9`, `release 1.4.9 build 149`, and `1.4.9+149` all parse as `1.4.9`.
Two rules protect users from bad input:

- Two or more dotted versions in one string (e.g. `1.4.9 requires iOS 15.6`)
  are ambiguous → the parser returns `null` and the gate fails open.
- Since 0.3.0, a Remote Config version value with no dotted core (e.g. a bare
  `140`) is rejected → fail open. Build codes are not version names; always
  enter a dotted version (`1.4.0`) in Remote Config.

**Recommendation for releases:** still enter a clean `major.minor.patch`
version string (e.g. `1.5.0`) in App Store Connect. Do not append the build
number — apps that ship with a pre-0.2.1 version of this package cannot parse
the suffix, and their store gate silently stops forcing updates.

## Reuse in another app

Supply a different `AppUpdateConfig`. No code changes. Add it to your
`pubspec.yaml`:

```yaml
dependencies:
  firebase_remote_update: ^0.3.0
```

## Using an API instead of Remote Config?

Use [`app_update_gate`](https://pub.dev/packages/app_update_gate) directly —
the same gate, service, and store checks with an HTTP policy source you
define (endpoint, auth, and JSON mapping), and no Firebase dependency.
