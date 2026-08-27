import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_remote_update/firebase_remote_update.dart';
import 'package:flutter_test/flutter_test.dart';

/// Remote Config stand-in with fully controllable values.
class _FakeRemoteConfig extends Fake implements FirebaseRemoteConfig {
  _FakeRemoteConfig({
    Map<String, String>? strings,
    Map<String, bool>? bools,
    this.fetchThrows = false,
  }) : _strings = strings ?? const {},
       _bools = bools ?? const {};

  final Map<String, String> _strings;
  final Map<String, bool> _bools;
  final bool fetchThrows;

  Map<String, dynamic>? capturedDefaults;

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    capturedDefaults = defaults;
  }

  @override
  Future<bool> fetchAndActivate() async {
    if (fetchThrows) throw Exception('network down');
    return true;
  }

  @override
  String getString(String key) => _strings[key] ?? '';

  @override
  bool getBool(String key) => _bools[key] ?? false;
}

const _config = AppUpdateConfig(
  androidPackageId: 'com.example.myapp',
  iosAppStoreId: '1234567890',
);

void main() {
  // The test host is neither iOS nor Android, so the source reads the
  // Android Remote Config keys.
  const k = RemoteConfigKeys();

  group('FirebaseRemoteConfigPolicySource.fetchPolicy', () {
    test('maps Remote Config values to an UpdatePolicy', () async {
      final source = FirebaseRemoteConfigPolicySource(
        config: _config,
        remoteConfig: _FakeRemoteConfig(
          strings: {
            k.minRequiredVersionAndroid: '1.3.0',
            k.recommendedVersionAndroid: '1.5.0',
            k.updateMessage: 'Please update.',
          },
          bools: {k.forceUpdateEnabled: true, k.ignoreStoreCheck: true},
        ),
      );

      final policy = await source.fetchPolicy();

      expect(policy.minRequiredVersion, '1.3.0');
      expect(policy.recommendedVersion, '1.5.0');
      expect(policy.message, 'Please update.');
      expect(policy.forceUpdateEnabled, isTrue);
      expect(policy.ignoreStoreCheck, isTrue);
    });

    test('maps absent values to a safe, never-forcing policy', () async {
      final source = FirebaseRemoteConfigPolicySource(
        config: _config,
        remoteConfig: _FakeRemoteConfig(),
      );

      final policy = await source.fetchPolicy();

      expect(policy.forceUpdateEnabled, isFalse);
      expect(policy.minRequiredVersion, isNull);
      expect(policy.recommendedVersion, isNull);
      expect(policy.ignoreStoreCheck, isFalse);
    });

    test('registers safe Remote Config defaults', () async {
      final fake = _FakeRemoteConfig();
      final source = FirebaseRemoteConfigPolicySource(
        config: _config,
        remoteConfig: fake,
      );

      await source.fetchPolicy();

      expect(fake.capturedDefaults?[k.forceUpdateEnabled], isFalse);
      expect(fake.capturedDefaults?[k.ignoreStoreCheck], isFalse);
    });

    test('serves cached values when the fetch fails', () async {
      final source = FirebaseRemoteConfigPolicySource(
        config: _config,
        remoteConfig: _FakeRemoteConfig(
          strings: {k.minRequiredVersionAndroid: '1.3.0'},
          bools: {k.forceUpdateEnabled: true},
          fetchThrows: true,
        ),
      );

      final policy = await source.fetchPolicy();

      expect(policy.minRequiredVersion, '1.3.0');
      expect(policy.forceUpdateEnabled, isTrue);
    });
  });
}
