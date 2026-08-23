import 'dart:io';

bool get isDesktopPlatform =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;
