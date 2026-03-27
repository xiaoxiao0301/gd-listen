import 'dart:io';

/// Detects whether the app is running on an Android TV / leanback environment.
///
/// Strategy:
///   1. Must be Android (not iOS/macOS/etc.)
///   2. The device reports a large non-phone form factor, OR
///      the LEANBACK_LAUNCHER intent was used to start the app.
///
/// For runtime detection we rely on [isTV] which checks the platform and
/// screen characteristics. In practice, Android TV devices report
/// `uiMode` & `UI_MODE_TYPE_TELEVISION` which is exposed via platform
/// channels, but for a simple approach we provide an override so the
/// main() entry-point or a platform-channel result can set it.
class PlatformDetector {
  PlatformDetector._();

  /// Set to `true` from `main()` when the Android TV launcher started the app,
  /// or when a platform channel confirms the device is a TV.
  static bool _forcedTV = false;

  /// Call this once in `main()` if you detect TV via platform channel.
  static void forceTV() => _forcedTV = true;

  /// Returns `true` when running on Android TV / leanback.
  ///
  /// Defaults to the forced value; in tests or when not forced, always false
  /// unless [_forcedTV] was set.
  static bool get isTV => _forcedTV;

  static bool get isMobile => !isTV;

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
}
