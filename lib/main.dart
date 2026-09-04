import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'audio/system_media.dart';
import 'platform/desktop_tray.dart';
import 'platform/desktop_window.dart';
import 'ui/radio_screen_v5.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await initializeSystemMediaControls();

  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    await acrylic.Window.initialize();

    const options = WindowOptions(
      size: Size(1140, 700),
      minimumSize: Size(600, 390),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: '1940s Radio',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.setSize(options.size!);
    await windowManager.setMinimumSize(options.minimumSize!);
    await windowManager.center();
    await windowManager.setTitle(options.title!);
    await windowManager.setTitleBarStyle(
      options.titleBarStyle!,
      windowButtonVisibility: options.windowButtonVisibility ?? false,
    );
    await windowManager.setAsFrameless();
    await windowManager.setPreventClose(true);
    await desktopTray.initialize();
  }

  runApp(const Radio1940sApp());

  if (isDesktopPlatform) {
    unawaited(_finishDesktopStartup());
  }
}

Future<void> _finishDesktopStartup() async {
  await Future<void>.delayed(const Duration(milliseconds: 120));

  try {
    await acrylic.Window.setEffect(
      effect: acrylic.WindowEffect.transparent,
      color: Colors.transparent,
    );
  } catch (error, stackTrace) {
    debugPrint('Transparent window effect unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.show();
    await windowManager.focus();
  } catch (error, stackTrace) {
    debugPrint('Desktop window show warning: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  await Future<void>.delayed(const Duration(milliseconds: 500));
  try {
    final visible = await windowManager.isVisible();
    if (visible != true) {
      await windowManager.show();
      await windowManager.focus();
    }
  } catch (error, stackTrace) {
    debugPrint('Desktop visibility failsafe warning: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class Radio1940sApp extends StatelessWidget {
  const Radio1940sApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '1940s Radio',
      color: Colors.transparent,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xff2a160f)),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xffffd894),
          secondary: Color(0xffc59555),
          surface: Color(0xff2a160f),
        ),
      ),
      home: const RadioScreenV5(),
    );
  }
}
