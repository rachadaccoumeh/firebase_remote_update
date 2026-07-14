/// Names of the Remote Config parameters that drive the update policy.
///
/// Defaults follow a `snake_case` convention. Override any key when a specific
/// Firebase project already uses different parameter names.
class RemoteConfigKeys {
  const RemoteConfigKeys({
    this.forceUpdateEnabled = 'force_update_enabled',
    this.minRequiredVersionAndroid = 'min_required_version_android',
    this.minRequiredVersionIos = 'min_required_version_ios',
    this.recommendedVersionAndroid = 'recommended_version_android',
    this.recommendedVersionIos = 'recommended_version_ios',
    this.ignoreStoreCheck = 'force_ignore_store_check',
    this.updateMessage = 'update_message',
  });

  /// Global kill switch. When `false`, no forced update is ever shown.
  final String forceUpdateEnabled;

  /// Minimum installable version below which the app is forced to update.
  final String minRequiredVersionAndroid;
  final String minRequiredVersionIos;

  /// Version below which a non-blocking "update available" prompt applies.
  final String recommendedVersionAndroid;
  final String recommendedVersionIos;

  /// Emergency override: force even if the target build is not yet on the
  /// store. Use only for genuine emergencies (security/data-integrity), since
  /// it can leave users with no installable build.
  final String ignoreStoreCheck;

  /// Optional message to display on the update screen.
  final String updateMessage;
}

/// Everything project-specific for the update module.
///
/// Supplying a different instance is all that is required to reuse the module
/// in another app / Firebase project — no code changes.
class AppUpdateConfig {
  const AppUpdateConfig({
    required this.androidPackageId,
    required this.iosAppStoreId,
    this.storeCountry = 'us',
    this.fetchTimeout = const Duration(seconds: 8),
    this.minimumFetchInterval = const Duration(hours: 1),
    this.keys = const RemoteConfigKeys(),
  });

  /// Android application id, e.g. `com.example.myapp`.
  final String androidPackageId;

  /// Numeric App Store id (without the leading `id`), e.g. `1234567890`.
  final String iosAppStoreId;

  /// Storefront/country code used for the App Store URL and iTunes lookup.
  final String storeCountry;

  /// Max time to wait for a Remote Config fetch / iTunes lookup.
  final Duration fetchTimeout;

  /// Remote Config cache window. Keep modest for update checks, but not so low
  /// that fetches get throttled.
  final Duration minimumFetchInterval;

  /// Remote Config parameter names.
  final RemoteConfigKeys keys;

  String get androidStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidPackageId';

  String get iosStoreUrl =>
      'https://apps.apple.com/$storeCountry/app/id$iosAppStoreId';
}
