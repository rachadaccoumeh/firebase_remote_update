import 'package:app_update_gate/app_update_gate.dart' as core;
import 'package:app_update_gate/app_update_gate.dart'
    show StoreAvailabilityChecker, UpdateDecision;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'app_update_config.dart';
import 'firebase_remote_config_policy_source.dart';

/// Decides whether the running app must update, backed by Firebase Remote
/// Config.
///
/// A thin wrapper over the `app_update_gate` core service, wired to a
/// [FirebaseRemoteConfigPolicySource]. Same guarantees as before: fails open
/// on any error, and forced updates are guarded by a real store-availability
/// check.
class AppUpdateService {
  AppUpdateService({
    required AppUpdateConfig config,
    FirebaseRemoteConfig? remoteConfig,
    StoreAvailabilityChecker? storeChecker,
  }) : _config = config,
       _remoteConfig = remoteConfig,
       _core = core.AppUpdateService(
         // Remote Config values are version names, so the scheme stays
         // semantic (the core default) — the pre-0.3 behavior.
         config: core.AppUpdateConfig(
           androidPackageId: config.androidPackageId,
           iosAppStoreId: config.iosAppStoreId,
           storeCountry: config.storeCountry,
           fetchTimeout: config.fetchTimeout,
         ),
         source: FirebaseRemoteConfigPolicySource(
           config: config,
           remoteConfig: remoteConfig,
         ),
         storeChecker: storeChecker,
       );

  final AppUpdateConfig _config;
  final FirebaseRemoteConfig? _remoteConfig;
  final core.AppUpdateService _core;

  AppUpdateConfig get config => _config;

  /// Evaluates the update policy for the running version.
  ///
  /// Always fails open (returns `UpdateRequirement.none`) on any error, so a
  /// misconfiguration or flaky network can never lock users out.
  Future<UpdateDecision> evaluate() => _core.evaluate();

  /// Emits once per Remote Config change published in the console (Firebase
  /// real-time Remote Config), after the new values are activated, so the
  /// next [evaluate] reads them. Errors are logged and dropped (fail open).
  Stream<void> configUpdates() {
    final remoteConfig = _remoteConfig ?? FirebaseRemoteConfig.instance;
    return remoteConfig.onConfigUpdated
        .asyncMap((_) => remoteConfig.activate())
        .map<void>((_) {})
        .handleError(
          (Object e) =>
              debugPrint('⚠️ Remote Config real-time updates failed: $e'),
        );
  }

  /// Starts the update: an immediate in-app update on Android (falling back to
  /// the store page), or the App Store page on iOS.
  Future<void> startUpdate() => _core.startUpdate();
}
