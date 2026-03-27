import 'package:flutter/material.dart';
import 'core/utils/platform_detector.dart';
import 'core/utils/theme.dart';
import 'mobile/app_shell.dart';
import 'tv/tv_app_shell.dart';

class PmusicApp extends StatelessWidget {
  const PmusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformDetector.isTV;
    return MaterialApp(
      title: 'pmusic',
      debugShowCheckedModeBanner: false,
      theme: isTV ? buildTvTheme() : buildMobileTheme(),
      home: isTV ? const TvAppShell() : const MobileAppShell(),
    );
  }
}
