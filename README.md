# firebase_remote_update

A small, reusable force/optional update gate for Flutter apps.

- **Policy source:** Firebase Remote Config (per-platform min & recommended versions, a global kill switch, an emergency override, and an optional message).
- **Safety gate:** before forcing, it verifies the target build is actually available on the store — Play In-App Update on Android, iTunes lookup on iOS — so users are never locked out of a build that isn't live yet.
- **Fails open:** any error (no network, bad config, throttled fetch) results in *no* forced update.

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

## Reuse in another app

Supply a different `AppUpdateConfig`. No code changes. Add it to your
`pubspec.yaml`:

```yaml
dependencies:
  firebase_remote_update: ^0.2.0
```

Or via git:

```yaml
dependencies:
  firebase_remote_update:
    git:
      url: https://github.com/rachadaccoumeh/firebase_remote_update.git
      ref: v0.2.0
```
