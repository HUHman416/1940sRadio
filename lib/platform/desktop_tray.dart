import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide MenuItem;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../audio/radio_player.dart';
import '../stations/station_store.dart';
import 'desktop_window.dart';

class DesktopTrayController with TrayListener {
  RadioPlayer? _radio;
  StationStore? _stations;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!isDesktopPlatform || _initialized) return;
    _initialized = true;
    trayManager.addListener(this);
    try {
      await trayManager.setIcon(_resolveIcon());
      await _rebuildMenu();
    } catch (error) {
      debugPrint('System tray unavailable: $error');
    }
  }

  void bind({required RadioPlayer radio, required StationStore stations}) {
    if (_radio != radio || _stations != stations) {
      _radio?.removeListener(_rebuildMenuUnawaited);
      _stations?.removeListener(_rebuildMenuUnawaited);
      _radio = radio;
      _stations = stations;
      radio.addListener(_rebuildMenuUnawaited);
      stations.addListener(_rebuildMenuUnawaited);
    }
    _rebuildMenuUnawaited();
  }

  String _resolveIcon() {
    final appDir = Platform.environment['APPDIR'];
    if (appDir != null && appDir.isNotEmpty) return '$appDir/radio1940s.png';
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.local/share/icons/hicolor/scalable/apps/radio1940s.svg';
  }

  void _rebuildMenuUnawaited() {
    unawaited(_rebuildMenu());
  }

  Future<void> _rebuildMenu() async {
    if (!_initialized) return;
    final radio = _radio;
    final stations = _stations;
    final items = <MenuItem>[
      MenuItem(key: 'show', label: 'Show 1940s Radio'),
      MenuItem.separator(),
    ];
    if (radio != null) {
      items.add(MenuItem(key: 'power', label: radio.poweredOn ? 'Power Off' : 'Power On'));
      items.add(MenuItem(key: 'volume_down', label: 'Volume -10%', disabled: radio.volume <= 0));
      items.add(MenuItem(key: 'volume_up', label: 'Volume +10%', disabled: radio.volume >= 100));
    }
    if (stations != null) {
      items.add(MenuItem.separator());
      for (var index = 0; index < stations.presets.length; index++) {
        final station = stations.stationById(stations.presets[index]);
        if (station != null) {
          items.add(MenuItem(key: 'preset:$index', label: 'Preset ${index + 1}: ${station.name}'));
        }
      }
    }
    items
      ..add(MenuItem.separator())
      ..add(MenuItem(key: 'quit', label: 'Quit'));
    await trayManager.setContextMenu(Menu(items: items));
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    final radio = _radio;
    final stations = _stations;
    if (key == 'show') {
      windowManager.show();
      windowManager.focus();
    } else if (key == 'power' && radio != null) {
      radio.togglePower();
    } else if (key == 'volume_down' && radio != null) {
      radio.setVolume(radio.volume - 10);
    } else if (key == 'volume_up' && radio != null) {
      radio.setVolume(radio.volume + 10);
    } else if (key != null && key.startsWith('preset:') && radio != null && stations != null) {
      final index = int.tryParse(key.substring(7));
      if (index != null && index >= 0 && index < stations.presets.length) {
        final station = stations.stationById(stations.presets[index]);
        if (station != null) {
          stations.selectStation(station);
          radio.tuneTo(station);
        }
      }
    } else if (key == 'quit') {
      unawaited(_quitFromTray());
    }
  }

  Future<void> _quitFromTray() async {
    await _radio?.shutdown();
    await dispose();
    try {
      await windowManager.destroy();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _radio?.removeListener(_rebuildMenuUnawaited);
    _stations?.removeListener(_rebuildMenuUnawaited);
    trayManager.removeListener(this);
    if (_initialized) {
      try {
        await trayManager.destroy();
      } catch (_) {}
    }
    _initialized = false;
  }
}

final desktopTray = DesktopTrayController();
