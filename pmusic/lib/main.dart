import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/utils/platform_detector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect whether this is an Android TV device via platform channel.
  await _detectTVMode();

  runApp(
    const ProviderScope(
      child: PmusicApp(),
    ),
  );
}

/// Queries Android's UiModeManager to determine if the device is a TV.
Future<void> _detectTVMode() async {
  if (!PlatformDetector.isAndroid) return;
  try {
    const channel = MethodChannel('com.private.pmusic/platform');
    final isTV = await channel.invokeMethod<bool>('isTV') ?? false;
    if (isTV) PlatformDetector.forceTV();
  } on MissingPluginException {
    // Channel not wired up yet — default to mobile mode.
  } catch (_) {
    // Silently fall back to mobile.
  }
}
