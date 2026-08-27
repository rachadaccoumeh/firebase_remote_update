import 'package:firebase_remote_update/firebase_remote_update.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Remote Config stand-in with fully controllable values.
class _FakeRemoteConfig extends Fake implements FirebaseRemoteConfig {
  _FakeRemoteConfig({Map<String, String>? strings, Map<String, bool>? bools})
    : _strings = strings ?? const {},
      _bools = bools ?? const {};

  final Map<String, String> _strings;
  final Map<String, bool> _bools;

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {}

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {}

  @override
  Future<bool> fetchAndActivate() async => true;

  @override
  String getString(String key) => _strings[key] ?? '';

  @override
  bool getBool(String key) => _bools[key] ?? false;
}

/// Store checker whose answer is fixed by the test.
class _FakeStoreChecker implements StoreAvailabilityChecker {
  _FakeStoreChecker(this._status);
  final StoreStatus _status;

  @override
  Future<StoreStatus> check({
    AppVersion? minRequired,
    AppVersion? currentVersion,
  }) async => _status;
}

const _config = AppUpdateConfig(
  androidPackageId: 'com.example.myapp',
  iosAppStoreId: '1234567890',
);

AppUpdateService _service({
  required Map<String, String> strings,
  required Map<String, bool> bools,
  required StoreStatus store,
}) {
  return AppUpdateService(
    config: _config,
    remoteConfig: _FakeRemoteConfig(strings: strings, bools: bools),
    storeChecker: _FakeStoreChecker(store),
  );
}

void main() {
  // The test host is neither iOS nor Android, so the service reads the
  // Android Remote Config keys. Current app version is pinned below.
  const k = RemoteConfigKeys();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'MyApp',
      packageName: 'com.example.myapp',
      version: '1.2.8',
      buildNumber: '128',
      buildSignature: '',
    );
  });

  group('AppUpdateService.evaluate', () {
    test(
      'forces update when below minimum and the build is on the store',
      () async {
        final decision =
            await _service(
              strings: {
                k.minRequiredVersionAndroid: '1.3.0',
                k.updateMessage: 'Please update.',
              },
              bools: {k.forceUpdateEnabled: true},
              store: const StoreStatus(
                isUpdateAvailable: true,
                latestStoreVersion: '1.3.0',
              ),
            ).evaluate();

        expect(decision.requirement, UpdateRequirement.forced);
        expect(decision.isForced, isTrue);
        expect(decision.message, 'Please update.');
      },
    );

    test(
      'does NOT force (fails open) when the build is not yet on the store',
      () async {
        final decision =
            await _service(
              strings: {k.minRequiredVersionAndroid: '1.3.0'},
              bools: {k.forceUpdateEnabled: true},
              store:
                  const StoreStatus.unknown(), // store gate says not available
            ).evaluate();

        // Below minimum but store can't confirm the build → never lock the user
        // out. No recommended set here, so the result is "none".
        expect(decision.isForced, isFalse);
        expect(decision.requirement, UpdateRequirement.none);
      },
    );

    test(
      'emergency ignore-store flag forces even without store confirmation',
      () async {
        final decision =
            await _service(
              strings: {k.minRequiredVersionAndroid: '1.3.0'},
              bools: {k.forceUpdateEnabled: true, k.ignoreStoreCheck: true},
              store: const StoreStatus.unknown(),
            ).evaluate();

        expect(decision.requirement, UpdateRequirement.forced);
      },
    );

    test(
      'does not force when the kill switch (force_update_enabled) is off',
      () async {
        final decision =
            await _service(
              strings: {k.minRequiredVersionAndroid: '1.3.0'},
              bools: {k.forceUpdateEnabled: false},
              store: const StoreStatus(isUpdateAvailable: true),
            ).evaluate();

        expect(decision.isForced, isFalse);
      },
    );

    test(
      'returns optional (soft prompt) when below recommended only',
      () async {
        final decision =
            await _service(
              strings: {k.recommendedVersionAndroid: '1.3.0'},
              bools: const {},
              store: const StoreStatus.unknown(),
            ).evaluate();

        expect(decision.requirement, UpdateRequirement.optional);
        expect(decision.isOptional, isTrue);
      },
    );

    test(
      'returns none when current version satisfies all thresholds',
      () async {
        final decision =
            await _service(
              strings: {
                k.minRequiredVersionAndroid: '1.2.0',
                k.recommendedVersionAndroid: '1.2.8',
              },
              bools: {k.forceUpdateEnabled: true},
              store: const StoreStatus(isUpdateAvailable: true),
            ).evaluate();

        expect(decision.isNone, isTrue);
      },
    );

    test('fails open to none when Remote Config values are absent', () async {
      final decision =
          await _service(
            strings: const {},
            bools: const {},
            store: const StoreStatus.unknown(),
          ).evaluate();

      expect(decision.isNone, isTrue);
    });
  });
}
