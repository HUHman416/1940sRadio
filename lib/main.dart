import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'audio/system_media.dart';
import 'platform/desktop_window.dart';
import 'ui/radio_screen_v3.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await initializeSystemMediaControls();

  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1040, 610),
      minimumSize: Size(560, 360),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: '1940s Radio',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setHasShadow(false);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const Radio1940sApp());
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
      ),
      home: const RadioScreenV3(),
    );
  }
}
