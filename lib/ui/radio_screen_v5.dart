import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../audio/radio_player.dart';
import '../features/receiver_features.dart';
import '../platform/desktop_tray.dart';
import '../platform/desktop_window.dart';
import '../stations/radio_station.dart';
import '../stations/station_store.dart';
import 'station_directory_dialog_v5.dart';

class RadioScreenV5 extends StatefulWidget {
  const RadioScreenV5({super.key});

  @override
  State<RadioScreenV5> createState() => _RadioScreenV5State();
}

class _RadioScreenV5State extends State<RadioScreenV5> with WindowListener {
  static const _windowXKey = 'window-x.v1';
  static const _windowYKey = 'window-y.v1';
  static const _windowWKey = 'window-width.v1';
  static const _windowHKey = 'window-height.v1';

  final radio = RadioPlayer();
  final stations = StationStore();
  final features = ReceiverFeatures();
  bool ready = false;
  bool _forceQuit = false;
  String? _lastHistoryTitle;
  double _tuningPosition = 0;
  Timer? _windowSaveDebounce;

  @override
  void initState() {
    super.initState();
    if (isDesktopPlatform) windowManager.addListener(this);
    radio.addListener(_captureNowPlaying);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await Future.wait([stations.load(), features.load()]);
      await radio.initialize(initialStation: stations.selectedStation);
      _syncTuningPosition();
      features.bind(
        onSleepElapsed: radio.powerOff,
        onSleepFade: radio.applySleepFade,
        onAlarm: _runAlarm,
      );
      desktopTray.bind(radio: radio, stations: stations);
      if (isDesktopPlatform) await _restoreWindowState();
    } catch (error, stackTrace) {
      debugPrint('Radio bootstrap warning: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) setState(() => ready = true);
    }
  }

  Future<void> _runAlarm() async {
    final station = stations.stationById(features.alarmStationId) ?? stations.selectedStation;
    await stations.selectStation(station);
    await radio.tuneTo(station);
    await radio.wakeAtVolume(features.alarmVolume, gentle: features.alarmGentle);
    if (isDesktopPlatform) {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  void _captureNowPlaying() {
    final title = radio.nowPlaying;
    if (title == null || title == _lastHistoryTitle || !features.loaded) return;
    _lastHistoryTitle = title;
    unawaited(features.recordNowPlaying(radio.station, title));
  }

  void _syncTuningPosition() {
    final index = stations.stations.indexWhere((station) => station.id == stations.selectedStationId);
    _tuningPosition = index < 0 ? 0 : index.toDouble();
  }

  Future<void> _selectStation(RadioStation station) async {
    await stations.selectStation(station);
    await radio.tuneTo(station);
    if (!mounted) return;
    setState(_syncTuningPosition);
  }

  Future<void> _tuneFromSlider(double value) async {
    if (stations.stations.isEmpty) return;
    final index = value.round().clamp(0, stations.stations.length - 1);
    await _selectStation(stations.stations[index]);
  }

  Future<void> _openDirectory() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StationDirectoryDialogV5(
        store: stations,
        onTune: _selectStation,
        testStream: radio.testStream,
      ),
    );
  }

  Future<void> _toggleCompact() async {
    final compact = !features.compactMode;
    await features.setCompactMode(compact);
    if (isDesktopPlatform) {
      await windowManager.setMinimumSize(compact ? const Size(500, 220) : const Size(600, 390));
      await windowManager.setSize(compact ? const Size(650, 270) : const Size(1140, 700));
    }
  }

  Future<void> _editAlarm() async {
    var enabled = features.alarmEnabled;
    var hour = features.alarmHour;
    var minute = features.alarmMinute;
    var daysMask = features.alarmDaysMask;
    var stationId = features.alarmStationId ?? stations.selectedStation.id;
    var volume = features.alarmVolume;
    var gentle = features.alarmGentle;

    final save = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: const Color(0xff3b2115),
              title: const Text('WAKE RECEIVER'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Alarm enabled'),
                        value: enabled,
                        onChanged: (value) => setDialogState(() => enabled = value),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Wake time'),
                        subtitle: Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'),
                        trailing: const Icon(Icons.schedule),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: hour, minute: minute),
                          );
                          if (picked != null) setDialogState(() { hour = picked.hour; minute = picked.minute; });
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text('DAYS', style: TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        children: List.generate(7, (index) {
                          const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final bit = 1 << index;
                          final selected = (daysMask & bit) != 0;
                          return FilterChip(
                            label: Text(labels[index]),
                            selected: selected,
                            onSelected: (value) => setDialogState(() {
                              if (value) {
                                daysMask |= bit;
                              } else if (daysMask != bit) {
                                daysMask &= ~bit;
                              }
                            }),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: stationId,
                        decoration: const InputDecoration(labelText: 'Wake station'),
                        items: stations.stations
                            .map((station) => DropdownMenuItem(value: station.id, child: Text(station.name)))
                            .toList(),
                        onChanged: (value) => setDialogState(() => stationId = value ?? stationId),
                      ),
                      const SizedBox(height: 12),
                      Text('WAKE VOLUME • ${volume.round()}%'),
                      Slider(
                        value: volume,
                        min: 5,
                        max: 100,
                        onChanged: (value) => setDialogState(() => volume = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Gentle tube warm-up'),
                        subtitle: const Text('Fade up instead of starting at full wake volume.'),
                        value: gentle,
                        onChanged: (value) => setDialogState(() => gentle = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE ALARM')),
              ],
            ),
          ),
        ) ??
        false;
    if (!save) return;
    await features.setAlarm(
      enabled: enabled,
      hour: hour,
      minute: minute,
      daysMask: daysMask,
      stationId: stationId,
      volume: volume,
      gentle: gentle,
    );
  }

  Future<void> _showHistory() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff3b2115),
        title: const Text('RECENT TRANSMISSIONS'),
        content: SizedBox(
          width: 560,
          height: 430,
          child: AnimatedBuilder(
            animation: features,
            builder: (context, _) => features.history.isEmpty
                ? const Center(child: Text('No program history yet.'))
                : ListView.builder(
                    itemCount: features.history.length,
                    itemBuilder: (context, index) {
                      final item = features.history[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.title),
                        subtitle: Text('${item.stationName} • ${item.at.toLocal()}'),
                      );
                    },
                  ),
          ),
        ),
        actions: [
          TextButton(onPressed: features.clearHistory, child: const Text('CLEAR')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Future<void> _exportConfiguration() async {
    final raw = stations.exportConfiguration();
    if (!isDesktopPlatform) {
      await _showConfigText('EXPORT RECEIVER CONFIGURATION', raw);
      return;
    }
    final location = await getSaveLocation(suggestedName: '1940sRadio-receiver.json');
    if (location == null) return;
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(raw)),
      mimeType: 'application/json',
      name: '1940sRadio-receiver.json',
    );
    await file.saveTo(location.path);
  }

  Future<void> _importConfiguration() async {
    const types = XTypeGroup(label: '1940s Radio receiver configuration', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: const [types]);
    if (file == null) return;
    try {
      await stations.importConfiguration(await file.readAsString());
      await _selectStation(stations.selectedStation);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not import configuration: $error')));
    }
  }

  Future<void> _showConfigText(String title, String raw) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 560, child: SelectableText(raw)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }

  Future<void> _restoreWindowState() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble(_windowWKey);
    final h = prefs.getDouble(_windowHKey);
    final x = prefs.getDouble(_windowXKey);
    final y = prefs.getDouble(_windowYKey);
    if (w != null && h != null) await windowManager.setSize(Size(w, h));
    if (x != null && y != null) await windowManager.setPosition(Offset(x, y));
  }

  void _scheduleWindowSave() {
    if (!isDesktopPlatform) return;
    _windowSaveDebounce?.cancel();
    _windowSaveDebounce = Timer(const Duration(milliseconds: 250), () => unawaited(_saveWindowState()));
  }

  Future<void> _saveWindowState() async {
    if (!isDesktopPlatform) return;
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowXKey, position.dx);
    await prefs.setDouble(_windowYKey, position.dy);
    await prefs.setDouble(_windowWKey, size.width);
    await prefs.setDouble(_windowHKey, size.height);
  }

  Future<void> _hideToTray() async {
    if (isDesktopPlatform) await windowManager.hide();
  }

  Future<void> _gracefulQuit() async {
    if (_forceQuit) return;
    _forceQuit = true;
    _windowSaveDebounce?.cancel();
    await _saveWindowState();
    await radio.shutdown();
    await desktopTray.dispose();
    if (isDesktopPlatform) await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (_forceQuit) return;
    unawaited(_hideToTray());
  }

  @override
  void onWindowMove() => _scheduleWindowSave();

  @override
  void onWindowResize() => _scheduleWindowSave();

  @override
  void dispose() {
    _windowSaveDebounce?.cancel();
    radio.removeListener(_captureNowPlaying);
    if (isDesktopPlatform) windowManager.removeListener(this);
    radio.dispose();
    stations.dispose();
    features.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(backgroundColor: Colors.transparent, body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([radio, stations, features]),
        builder: (context, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: features.compactMode ? _buildCompact() : _buildFull(),
          ),
        ),
      ),
    );
  }

  Widget _cabinet({required Widget child, double radius = 32}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xff180a06), width: 5),
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xff8f4a29), Color(0xff5b2b18), Color(0xff31160f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 22, offset: Offset(0, 12))],
      ),
      child: child,
    );
  }

  Widget _buildFull() {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1120,
          height: 660,
          child: _cabinet(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 10, child: _buildControls()),
                        const SizedBox(width: 18),
                        Expanded(flex: 13, child: _buildDial()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFavoritesRail(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 630,
        height: 245,
        child: _cabinet(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              children: [
                _buildHeader(compact: true),
                const SizedBox(height: 6),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(radio.station.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xffffd98c), fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text(radio.nowPlaying ?? _statusText, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xffd4ad76), fontSize: 11)),
                            const SizedBox(height: 8),
                            _buildTuningSlider(compact: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 180,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(child: _action(radio.poweredOn ? 'ON' : 'OFF', Icons.power_settings_new, radio.togglePower, active: radio.poweredOn)),
                                const SizedBox(width: 6),
                                Expanded(child: _action('FULL', Icons.open_in_full, _toggleCompact)),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(Icons.volume_down, size: 16, color: Color(0xffd4ad76)),
                                Expanded(child: Slider(value: radio.volume, min: 0, max: 100, onChanged: radio.setVolume)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool compact = false}) {
    return Row(
      children: [
        if (isDesktopPlatform) ...[
          _roundButton(
            stations.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            stations.pinned ? 'Unlock position' : 'Lock position',
            () => stations.setPinned(!stations.pinned),
            active: stations.pinned,
          ),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: isDesktopPlatform && !stations.pinned
              ? DragToMoveArea(
                  child: SizedBox(
                    height: 32,
                    child: Center(
                      child: Text(compact ? 'DRIFT BAY RECEIVER • COMPACT' : 'DRIFT BAY RECEIVER • FP-50 • BUILD 0.5',
                          style: const TextStyle(color: Color(0xffc49a68), fontSize: 9, letterSpacing: 1.8)),
                    ),
                  ),
                )
              : Center(
                  child: Text(compact ? 'DRIFT BAY RECEIVER • COMPACT' : 'DRIFT BAY RECEIVER • FP-50 • BUILD 0.5',
                      style: const TextStyle(color: Color(0xffc49a68), fontSize: 9, letterSpacing: 1.8)),
                ),
        ),
        if (!compact) ...[
          _roundButton(Icons.swap_horiz, 'Compact receiver', _toggleCompact),
          const SizedBox(width: 6),
        ],
        if (isDesktopPlatform) ...[
          _roundButton(Icons.remove, 'Minimize', windowManager.minimize),
          const SizedBox(width: 6),
          _roundButton(Icons.close, 'Hide to tray', _hideToTray),
          const SizedBox(width: 6),
          _roundButton(Icons.logout, 'Quit', _gracefulQuit),
        ],
      ],
    );
  }

  Widget _buildControls() {
    final sleep = features.sleepRemaining;
    final sleepLabel = sleep == null ? 'OFF' : '${sleep.inMinutes + 1}m';
    return _panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _clockPanel()),
                const SizedBox(width: 8),
                _signalEye(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _action(radio.poweredOn ? 'POWER • ON' : 'POWER • OFF', Icons.power_settings_new, radio.togglePower, active: radio.poweredOn)),
                const SizedBox(width: 7),
                Expanded(child: _action(features.lampEnabled ? 'DIAL LAMP • ON' : 'DIAL LAMP • OFF', Icons.lightbulb_outline,
                    () => features.setLampEnabled(!features.lampEnabled), active: features.lampEnabled)),
              ],
            ),
            const SizedBox(height: 10),
            _panel(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  children: [
                    Row(children: [const Text('VOLUME', style: TextStyle(color: Color(0xffd4ad76), fontSize: 9)), const Spacer(), Text('${radio.volume.round()}%')]),
                    Slider(value: radio.volume, min: 0, max: 100, onChanged: radio.setVolume),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildPresets(),
            const Spacer(),
            Row(
              children: [
                Expanded(child: _action('SLEEP • $sleepLabel', Icons.bedtime_outlined, _cycleSleep)),
                const SizedBox(width: 6),
                Expanded(child: _action('ALARM • ${features.alarmEnabled ? features.alarmLabel : 'OFF'}', Icons.alarm, _editAlarm, active: features.alarmEnabled)),
                const SizedBox(width: 6),
                Expanded(child: _action('HISTORY', Icons.history, _showHistory)),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: _action('ATMOS • ${radio.atmosphereMode.name.toUpperCase()}', Icons.graphic_eq, _cycleAtmosphere)),
                const SizedBox(width: 6),
                Expanded(child: _action('IMPORT', Icons.file_open_outlined, _importConfiguration)),
                const SizedBox(width: 6),
                Expanded(child: _action('EXPORT', Icons.save_alt, _exportConfiguration)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _clockPanel() {
    String clock(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    return _panel(
      child: SizedBox(
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('FOGPOINT STANDARD TIME', style: TextStyle(color: Color(0xffd2a56d), fontSize: 8, letterSpacing: 1.4)),
            Text(clock(features.fogPointTime), style: const TextStyle(color: Color(0xffffd98c), fontSize: 25, fontWeight: FontWeight.bold)),
            Text('LOCAL ${clock(DateTime.now())}', style: const TextStyle(color: Color(0xffa97e55), fontSize: 8)),
          ],
        ),
      ),
    );
  }

  Widget _signalEye() {
    final active = radio.poweredOn && radio.connectionState == RadioConnectionState.playing;
    final seeking = radio.warmingUp || radio.connectionState == RadioConnectionState.connecting;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 76,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: active ? const Color(0xff2d7c43) : seeking ? const Color(0xff6a6a2d) : const Color(0xff17301f),
            border: Border.all(color: const Color(0xff100806), width: 4),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: active ? 12 : seeking ? 32 : 54,
              height: 24,
              decoration: BoxDecoration(color: const Color(0xff0b1710), borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ),
        const Text('SIGNAL EYE', style: TextStyle(color: Color(0xffaa8159), fontSize: 7)),
      ],
    );
  }

  Widget _buildDial() {
    final illuminated = radio.poweredOn && features.lampEnabled;
    return _panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: illuminated
                        ? const [Color(0xffffdd8a), Color(0xffc88b3b)]
                        : const [Color(0xff796449), Color(0xff44372b)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(radio.station.name,
                          style: TextStyle(color: illuminated ? const Color(0xff402313) : const Color(0xff28231e), fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
                      _buildTuningSlider(),
                      Text(_statusText,
                          style: TextStyle(color: illuminated ? const Color(0xff4d2a16) : const Color(0xff2b2722), fontWeight: FontWeight.bold, letterSpacing: 1.8)),
                      Column(
                        children: [
                          Text('NOW PLAYING', style: TextStyle(color: illuminated ? const Color(0xff6b3d20) : const Color(0xff302b25), fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(radio.poweredOn ? (radio.nowPlaying ?? 'PROGRAM INFORMATION UNAVAILABLE') : '—',
                              maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: illuminated ? const Color(0xff3d2113) : const Color(0xff211f1c), fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (radio.connectionState == RadioConnectionState.error)
                        TextButton.icon(onPressed: radio.retry, icon: const Icon(Icons.refresh), label: const Text('RETRY SIGNAL')),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              radio.station.subtitle.isEmpty ? 'INTERNET BROADCAST RECEIVER' : radio.station.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xffc9a16c), fontSize: 9, letterSpacing: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTuningSlider({bool compact = false}) {
    final count = stations.stations.length;
    final max = math.max(1, count - 1).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text('TUNE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.4)),
            const Spacer(),
            if (!compact) Text('${(_tuningPosition + 1).round().clamp(1, count)} / $count', style: const TextStyle(fontSize: 8)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: compact ? 4 : 8,
            activeTrackColor: const Color(0xff8e1e16),
            inactiveTrackColor: const Color(0xff55331f),
            thumbColor: const Color(0xffd6aa63),
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 7 : 11),
          ),
          child: Slider(
            value: _tuningPosition.clamp(0, max),
            min: 0,
            max: max,
            divisions: count > 1 ? count - 1 : 1,
            onChanged: count <= 1 ? null : (value) => setState(() => _tuningPosition = value),
            onChangeEnd: count <= 1 ? null : _tuneFromSlider,
          ),
        ),
        if (!compact)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stations.stations.first.name, style: const TextStyle(fontSize: 7)),
              if (count > 1) Text(stations.stations.last.name, style: const TextStyle(fontSize: 7)),
            ],
          ),
      ],
    );
  }

  Widget _buildPresets() {
    return _panel(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const Text('MECHANICAL PRESETS', style: TextStyle(color: Color(0xffbb8e5c), fontSize: 8, letterSpacing: 1.4)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final assigned = stations.stationById(stations.presets[index]);
                final active = assigned?.id == radio.station.id;
                return GestureDetector(
                  onTap: () async {
                    if (assigned == null) {
                      await stations.assignPreset(index, radio.station);
                    } else {
                      await _selectStation(assigned);
                    }
                  },
                  onLongPress: () => stations.assignPreset(index, radio.station),
                  onSecondaryTap: () => stations.clearPreset(index),
                  child: Tooltip(
                    message: assigned?.name ?? 'Assign current station to preset ${index + 1}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 42,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(colors: active ? const [Color(0xffffe2a0), Color(0xffb77d3c)] : const [Color(0xffd8bd88), Color(0xff80613e)]),
                        border: Border.all(color: const Color(0xff160a06), width: 2),
                      ),
                      child: Text('${index + 1}', style: const TextStyle(color: Color(0xff2d170f), fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesRail() {
    final favoriteStations = stations.favorites;
    return SizedBox(
      height: 72,
      child: _panel(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.star, color: Color(0xffffd894), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: favoriteStations.isEmpty
                    ? const Text('NO FAVORITES')
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favoriteStations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final station = favoriteStations[index];
                          return ActionChip(
                            label: Text(station.name),
                            avatar: station.id == radio.station.id ? const Icon(Icons.radio, size: 16) : null,
                            onPressed: () => _selectStation(station),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 8),
              _action('DIRECTORY', Icons.library_music_outlined, _openDirectory),
            ],
          ),
        ),
      ),
    );
  }

  String get _statusText {
    if (radio.warmingUp) return 'TUBES WARMING';
    return switch (radio.connectionState) {
      RadioConnectionState.off => 'RECEIVER OFF',
      RadioConnectionState.connecting => 'SEEKING SIGNAL',
      RadioConnectionState.playing => 'ON THE AIR',
      RadioConnectionState.error => 'SIGNAL LOST',
    };
  }

  Future<void> _cycleSleep() async {
    final minutes = features.sleepRemaining?.inMinutes;
    final next = switch (minutes) {
      null => const Duration(minutes: 15),
      < 20 => const Duration(minutes: 30),
      < 38 => const Duration(minutes: 45),
      < 53 => const Duration(minutes: 60),
      < 90 => const Duration(minutes: 120),
      _ => null,
    };
    await features.setSleepTimer(next);
  }

  Future<void> _cycleAtmosphere() async {
    final next = switch (radio.atmosphereMode) {
      AtmosphereMode.off => AtmosphereMode.subtle,
      AtmosphereMode.subtle => AtmosphereMode.period,
      AtmosphereMode.period => AtmosphereMode.off,
    };
    await radio.setAtmosphereMode(next);
  }

  Widget _panel({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: const Color(0xff24120c),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xff120806), width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: child,
      );

  Widget _action(String label, IconData icon, FutureOr<void> Function() onTap, {bool active = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: LinearGradient(colors: active ? const [Color(0xffffd58a), Color(0xffa67135)] : const [Color(0xffc8a16b), Color(0xff765333)]),
            border: Border.all(color: const Color(0xff25120c), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: const Color(0xff30170e)),
              const SizedBox(width: 5),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Color(0xff30170e), fontSize: 9, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, String tooltip, FutureOr<void> Function() onTap, {bool active = false}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xffc59555) : const Color(0xff2a160f),
              border: Border.all(color: const Color(0xff160a06), width: 2),
            ),
            child: Icon(icon, size: 16, color: active ? const Color(0xff2a160f) : const Color(0xffd4ad76)),
          ),
        ),
      ),
    );
  }
}
