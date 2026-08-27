import 'package:app_update_gate/app_update_gate.dart' as core;
import 'package:app_update_gate/app_update_gate.dart'
    show StoreAvailabilityChecker, UpdateDecision;
import 'package:firebase_remote_config/firebase_remote_config.dart';

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
  final core.AppUpdateService _core;

  AppUpdateConfig get config => _config;

  /// Evaluates the update policy for the running version.
  ///
  /// Always fails open (returns `UpdateRequirement.none`) on any error, so a
  /// misconfiguration or flaky network can never lock users out.
  Future<UpdateDecision> evaluate() => _core.evaluate();

  /// Starts the update: an immediate in-app update on Android (falling back to
  /// the store page), or the App Store page on iOS.
  Future<void> startUpdate() => _core.startUpdate();
}
