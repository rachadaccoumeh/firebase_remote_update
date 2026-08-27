import 'dart:io' show Platform;

import 'package:app_update_gate/app_update_gate.dart'
    show UpdatePolicy, UpdatePolicySource;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'app_update_config.dart';

/// Serves the update policy from Firebase Remote Config.
///
/// Prepares Remote Config (settings, safe defaults, fetch) on every
/// [fetchPolicy] call and maps the platform-specific parameter names from
/// [RemoteConfigKeys] to a single-platform [UpdatePolicy]. A failed fetch
/// falls back to cached/default values, and the core service fails open on
/// anything worse.
class FirebaseRemoteConfigPolicySource implements UpdatePolicySource {
  FirebaseRemoteConfigPolicySource({
    required AppUpdateConfig config,
    FirebaseRemoteConfig? remoteConfig,
  }) : _config = config,
       _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final AppUpdateConfig _config;
  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<UpdatePolicy> fetchPolicy() async {
    await _prepareRemoteConfig();

    final keys = _config.keys;
    return UpdatePolicy(
      forceUpdateEnabled: _remoteConfig.getBool(keys.forceUpdateEnabled),
      minRequiredVersion: _nonEmpty(_remoteConfig.getString(_minKey)),
      recommendedVersion: _nonEmpty(_remoteConfig.getString(_recommendedKey)),
      ignoreStoreCheck: _remoteConfig.getBool(keys.ignoreStoreCheck),
      message: _remoteConfig.getString(keys.updateMessage),
    );
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

  String? _nonEmpty(String value) => value.isEmpty ? null : value;

  String get _minKey =>
      Platform.isIOS
          ? _config.keys.minRequiredVersionIos
          : _config.keys.minRequiredVersionAndroid;

  String get _recommendedKey =>
      Platform.isIOS
          ? _config.keys.recommendedVersionIos
          : _config.keys.recommendedVersionAndroid;
}
