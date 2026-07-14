import 'dart:io' show Platform;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_config.dart';
import 'app_version.dart';
import 'store_availability_checker.dart';
import 'update_decision.dart';

/// Decides whether the running app must update, backed by Firebase Remote
/// Config and guarded by a real store-availability check.
///
/// Depends only on injected abstractions ([AppUpdateConfig],
/// [FirebaseRemoteConfig], [StoreAvailabilityChecker]), so it is easy to unit
/// test and to reuse across apps by supplying a different config.
class AppUpdateService {
  AppUpdateService({
    required AppUpdateConfig config,
    FirebaseRemoteConfig? remoteConfig,
    StoreAvailabilityChecker? storeChecker,
  }) : _config = config,
       _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance,
       _storeChecker =
           storeChecker ?? StoreAvailabilityChecker.forPlatform(config);

  final AppUpdateConfig _config;
  final FirebaseRemoteConfig _remoteConfig;
  final StoreAvailabilityChecker _storeChecker;

  AppUpdateConfig get config => _config;

  /// Evaluates the update policy for the running version.
  ///
  /// Always fails open (returns [UpdateRequirement.none]) on any error, so a
  /// misconfiguration or flaky network can never lock users out.
  Future<UpdateDecision> evaluate() async {
    try {
      await _prepareRemoteConfig();

      final current = await _currentVersion();
      if (current == null) return const UpdateDecision.none();

      final message = _remoteConfig.getString(_config.keys.updateMessage);
      final minRequired = AppVersion.tryParse(_remoteConfig.getString(_minKey));
      final recommended = AppVersion.tryParse(
        _remoteConfig.getString(_recommendedKey),
      );

      final forcingEnabled = _remoteConfig.getBool(
        _config.keys.forceUpdateEnabled,
      );
      final belowMinimum = minRequired != null && current < minRequired;

      if (forcingEnabled && belowMinimum) {
        final forced = await _resolveForced(minRequired, message);
        // When the store gate fails open, `forced` is null and we fall through
        // to a soft prompt instead of blocking the user.
        if (forced != null) return forced;
      }

      if (recommended != null && current < recommended) {
        return UpdateDecision(
          requirement: UpdateRequirement.optional,
          message: message,
        );
      }
      return const UpdateDecision.none();
    } catch (e) {
      debugPrint('⚠️ Update evaluation failed, allowing app to continue: $e');
      return const UpdateDecision.none();
    }
  }

  /// Starts the update: an immediate in-app update on Android (falling back to
  /// the store page), or the App Store page on iOS.
  Future<void> startUpdate() async {
    if (Platform.isAndroid) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
      } catch (e) {
        debugPrint('⚠️ In-app update failed, opening store page: $e');
      }
    }
    await _openStorePage();
  }

  // --- internals -----------------------------------------------------------

  Future<UpdateDecision?> _resolveForced(
    AppVersion minRequired,
    String message,
  ) async {
    // Emergency override: skip the store gate and force regardless.
    if (_remoteConfig.getBool(_config.keys.ignoreStoreCheck)) {
      return UpdateDecision(
        requirement: UpdateRequirement.forced,
        message: message,
      );
    }

    final status = await _storeChecker.check(minRequired);
    if (status.isUpdateAvailable) {
      return UpdateDecision(
        requirement: UpdateRequirement.forced,
        message: message,
        latestStoreVersion: status.latestStoreVersion,
      );
    }
    return null;
  }

  Future<void> _prepareRemoteConfig() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: _config.fetchTimeout,
        minimumFetchInterval: _config.minimumFetchInterval,
      ),
    );
    await _remoteConfig.setDefaults(_defaults());
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('⚠️ Remote Config fetch failed, using cached values: $e');
    }
  }

  Map<String, dynamic> _defaults() {
    final keys = _config.keys;
    return <String, dynamic>{
      // Safe defaults: never force when nothing has been fetched.
      keys.forceUpdateEnabled: false,
      keys.minRequiredVersionAndroid: '0.0.0',
      keys.minRequiredVersionIos: '0.0.0',
      keys.recommendedVersionAndroid: '0.0.0',
      keys.recommendedVersionIos: '0.0.0',
      keys.ignoreStoreCheck: false,
      keys.updateMessage: '',
    };
  }

  Future<AppVersion?> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersion.tryParse(info.version);
    } catch (e) {
      debugPrint('⚠️ Could not read package version: $e');
      return null;
    }
  }

  String get _minKey =>
      Platform.isIOS
          ? _config.keys.minRequiredVersionIos
          : _config.keys.minRequiredVersionAndroid;

  String get _recommendedKey =>
      Platform.isIOS
          ? _config.keys.recommendedVersionIos
          : _config.keys.recommendedVersionAndroid;

  Future<void> _openStorePage() async {
    final url = Platform.isIOS ? _config.iosStoreUrl : _config.androidStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('❌ Could not launch store URL: $url');
    }
  }
}
