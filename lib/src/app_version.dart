/// Immutable semantic version (`major.minor.patch`) with tolerant parsing.
///
/// Kept dependency-free and self-contained so the whole module stays portable
/// across apps. Build metadata (anything after `+`) is intentionally ignored,
/// because store/version-name comparisons only care about the release number.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Parses strings such as `1.2.8` or `1.2.8+128`.
  ///
  /// Missing trailing segments default to `0`. Returns `null` when the input
  /// is null/empty or contains a non-numeric segment, so callers can fail open.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final core = raw.split('+').first.trim();
    if (core.isEmpty) return null;

    final numbers = <int>[];
    for (final segment in core.split('.').take(3)) {
      final value = int.tryParse(segment.trim());
      if (value == null) return null;
      numbers.add(value);
    }
    if (numbers.isEmpty) return null;
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return AppVersion(numbers[0], numbers[1], numbers[2]);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
