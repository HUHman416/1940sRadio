import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../audio/radio_player.dart';
import '../features/receiver_features.dart';
import '../platform/desktop_window.dart';
import '../stations/radio_station.dart';
import '../stations/station_store.dart';
import 'station_directory_dialog.dart';

class RadioScreenV4 extends StatefulWidget {
  const RadioScreenV4({super.key});

  @override
  State<RadioScreenV4> createState() => _RadioScreenV4State();
}

class _RadioScreenV4State extends State<RadioScreenV4> {
  late final RadioPlayer radio = RadioPlayer();
  late final StationStore stations = StationStore();
  late final ReceiverFeatures features = ReceiverFeatures();
  bool ready = false;
  String? _lastHistoryTitle;

  @override
  void initState() {
    super.initState();
    radio.addListener(_captureNowPlaying);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await Future.wait([stations.load(), features.load()]);
      await radio.initialize(initialStation: stations.selectedStation);
      features.bind(
        onSleepElapsed: radio.powerOff,
        onAlarm: radio.powerOn,
      );
    } catch (error, stackTrace) {
      debugPrint('Radio bootstrap warning: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) setState(() => ready = true);
    }
  }

  void _captureNowPlaying() {
    final title = radio.nowPlaying;
    if (title == null || title == _lastHistoryTitle || !features.loaded) return;
    _lastHistoryTitle = title;
    features.recordNowPlaying(radio.station, title);
  }

  Future<void> _selectStation(RadioStation station) async {
    await stations.selectStation(station);
    await radio.tuneTo(station);
  }

  Future<void> _openDirectory() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StationDirectoryDialog(
        store: stations,
        onTune: _selectStation,
      ),
    );
  }

  Future<void> _editAlarm() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: features.alarmHour, minute: features.alarmMinute),
      helpText: 'SET RECEIVER ALARM',
    );
    if (picked == null) return;
    await features.setAlarm(
      enabled: true,
      hour: picked.hour,
      minute: picked.minute,
    );
  }

  Future<void> _showHistory() async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xff2a160f),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'RECENT TRANSMISSIONS',
                  style: TextStyle(
                    color: Color(0xffe3bd7d),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: features.history.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No program history yet.',
                            style: TextStyle(color: Color(0xffc8a477)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: features.history.length,
                          itemBuilder: (context, index) {
                            final item = features.history[index];
                            final time = item.at.toLocal();
                            return ListTile(
                              dense: true,
                              title: Text(
                                item.title,
                                style: const TextStyle(color: Color(0xffffdda0)),
                              ),
                              subtitle: Text(
                                '${item.stationName} • ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Color(0xffb88d60)),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await features.clearHistory();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Text('CLEAR'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CLOSE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    radio.removeListener(_captureNowPlaying);
    radio.dispose();
    stations.dispose();
    features.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final portrait = constraints.maxHeight > constraints.maxWidth * 1.08;
          final designSize = portrait ? const Size(440, 860) : const Size(1120, 660);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: designSize.width,
                  height: designSize.height,
                  child: ready
                      ? AnimatedBuilder(
                          animation: Listenable.merge([radio, stations, features]),
                          builder: (context, _) => _Cabinet(
                            portrait: portrait,
                            radio: radio,
                            stations: stations,
                            features: features,
                            onSelectStation: _selectStation,
                            onOpenDirectory: _openDirectory,
                            onEditAlarm: _editAlarm,
                            onShowHistory: _showHistory,
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cabinet extends StatelessWidget {
  const _Cabinet({
    required this.portrait,
    required this.radio,
    required this.stations,
    required this.features,
    required this.onSelectStation,
    required this.onOpenDirectory,
    required this.onEditAlarm,
    required this.onShowHistory,
  });

  final bool portrait;
  final RadioPlayer radio;
  final StationStore stations;
  final ReceiverFeatures features;
  final Future<void> Function(RadioStation) onSelectStation;
  final VoidCallback onOpenDirectory;
  final VoidCallback onEditAlarm;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final stationIndex = stations.stations.indexWhere(
      (station) => station.id == stations.selectedStationId,
    );
    final dial = _Dial(
      radio: radio,
      lampEnabled: features.lampEnabled,
      stationIndex: stationIndex,
      stationCount: stations.stations.length,
      movable: !stations.pinned,
    );
    final controlBay = _ControlBay(
      radio: radio,
      stations: stations,
      features: features,
      onSelectStation: onSelectStation,
      onEditAlarm: onEditAlarm,
      onShowHistory: onShowHistory,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xff180a06), width: 5),
        borderRadius: BorderRadius.circular(portrait ? 28 : 38),
        gradient: const LinearGradient(
          colors: [Color(0xff8f4a29), Color(0xff5b2b18), Color(0xff31160f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 22, offset: Offset(0, 12)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(portrait ? 14 : 22, 12, portrait ? 14 : 22, 14),
        child: Column(
          children: [
            _Header(
              pinned: stations.pinned,
              onTogglePin: () => stations.setPinned(!stations.pinned),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: portrait
                  ? Column(
                      children: [
                        Expanded(flex: 10, child: dial),
                        const SizedBox(height: 10),
                        Expanded(flex: 11, child: controlBay),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 10, child: controlBay),
                        const SizedBox(width: 18),
                        Expanded(flex: 12, child: dial),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: portrait ? 92 : 88,
              child: _ChannelRail(
                stations: stations,
                currentStation: radio.station,
                onSelectStation: onSelectStation,
                onOpenDirectory: onOpenDirectory,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pinned, required this.onTogglePin});
  final bool pinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) {
      return const SizedBox(
        height: 24,
        child: Center(
          child: Text(
            'DRIFT BAY RECEIVER • FP-40',
            style: TextStyle(color: Color(0xffd2aa73), fontSize: 9, letterSpacing: 2),
          ),
        ),
      );
    }
    return Row(
      children: [
        _RoundButton(
          tooltip: pinned ? 'Unlock radio position' : 'Lock radio position',
          icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
          active: pinned,
          onPressed: onTogglePin,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MoveArea(
            enabled: !pinned,
            child: SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  pinned ? 'POSITION LOCKED' : 'DRAG RADIO TO MOVE',
                  style: const TextStyle(
                    color: Color(0xffc49a68),
                    fontSize: 9,
                    letterSpacing: 2.1,
                  ),
                ),
              ),
            ),
          ),
        ),
        _RoundButton(tooltip: 'Minimize', icon: Icons.remove, onPressed: windowManager.minimize),
        const SizedBox(width: 6),
        _RoundButton(tooltip: 'Close', icon: Icons.close, onPressed: windowManager.close),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? const Color(0xffc59555) : const Color(0xff2a160f),
                border: Border.all(color: const Color(0xff160a06), width: 2),
              ),
              child: Icon(
                icon,
                size: 16,
                color: active ? const Color(0xff2a160f) : const Color(0xffd4ad76),
              ),
            ),
          ),
        ),
      );
}

class _MoveArea extends StatelessWidget {
  const _MoveArea({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform || !enabled) return child;
    return DragToMoveArea(child: child);
  }
}

class _ControlBay extends StatelessWidget {
  const _ControlBay({
    required this.radio,
    required this.stations,
    required this.features,
    required this.onSelectStation,
    required this.onEditAlarm,
    required this.onShowHistory,
  });

  final RadioPlayer radio;
  final StationStore stations;
  final ReceiverFeatures features;
  final Future<void> Function(RadioStation) onSelectStation;
  final VoidCallback onEditAlarm;
  final VoidCallback onShowHistory;

  String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final fst = features.fogPointTime;
    final local = DateTime.now();
    final sleep = features.sleepRemaining;
    final sleepText = sleep == null
        ? 'OFF'
        : '${sleep.inMinutes}:${(sleep.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x55200e08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff2a120b), width: 3),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InsetPanel(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'FOGPOINT STANDARD TIME',
                        style: TextStyle(
                          color: Color(0xffd2a56d),
                          fontSize: 9,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _clock(fst),
                        style: const TextStyle(
                          color: Color(0xffffd98c),
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'LOCAL ${_clock(local)}',
                        style: const TextStyle(
                          color: Color(0xffa97e55),
                          fontSize: 8,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TuningEye(radio: radio),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _VintageAction(
                  label: radio.poweredOn ? 'POWER • ON' : 'POWER • OFF',
                  icon: Icons.power_settings_new,
                  active: radio.poweredOn,
                  onTap: radio.togglePower,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VintageAction(
                  label: features.lampEnabled ? 'DIAL LAMP • ON' : 'DIAL LAMP • OFF',
                  icon: Icons.lightbulb_outline,
                  active: features.lampEnabled,
                  onTap: () => features.setLampEnabled(!features.lampEnabled),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InsetPanel(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'VOLUME',
                        style: TextStyle(color: Color(0xffd4ad76), fontSize: 9, letterSpacing: 1.5),
                      ),
                      const Spacer(),
                      Text(
                        '${radio.volume.round()}%',
                        style: const TextStyle(color: Color(0xffffd98c), fontSize: 10),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: const Color(0xffc9944f),
                      inactiveTrackColor: const Color(0xff30160f),
                      thumbColor: const Color(0xffe0b66f),
                      overlayColor: const Color(0x22ffd98c),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    ),
                    child: Slider(
                      value: radio.volume,
                      min: 0,
                      max: 100,
                      onChanged: radio.setVolume,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Presets(
            store: stations,
            currentStation: radio.station,
            enabled: radio.poweredOn,
            onSelectStation: onSelectStation,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _VintageAction(
                  label: 'SLEEP • $sleepText',
                  icon: Icons.bedtime_outlined,
                  onTap: () {
                    final current = sleep?.inMinutes;
                    final next = switch (current) {
                      null => const Duration(minutes: 15),
                      < 25 => const Duration(minutes: 30),
                      < 50 => const Duration(minutes: 60),
                      < 80 => const Duration(minutes: 90),
                      _ => null,
                    };
                    features.setSleepTimer(next);
                  },
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _VintageAction(
                  label: 'ALARM • ${features.alarmEnabled ? features.alarmLabel : 'OFF'}',
                  icon: Icons.alarm,
                  active: features.alarmEnabled,
                  onTap: onEditAlarm,
                  onLongPress: () => features.setAlarm(
                    enabled: !features.alarmEnabled,
                    hour: features.alarmHour,
                    minute: features.alarmMinute,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _VintageAction(
                  label: 'HISTORY',
                  icon: Icons.history,
                  onTap: onShowHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsetPanel extends StatelessWidget {
  const _InsetPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xff24120c),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xff120806), width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

class _TuningEye extends StatelessWidget {
  const _TuningEye({required this.radio});
  final RadioPlayer radio;

  @override
  Widget build(BuildContext context) {
    final active = radio.poweredOn && radio.connectionState == RadioConnectionState.playing;
    final warming = radio.warmingUp || radio.connectionState == RadioConnectionState.connecting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          width: 74,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: active
                ? const Color(0xff2d7c43)
                : warming
                    ? const Color(0xff6a6a2d)
                    : const Color(0xff17301f),
            border: Border.all(color: const Color(0xff100806), width: 4),
            boxShadow: active
                ? const [BoxShadow(color: Color(0x8836ff76), blurRadius: 18)]
                : null,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              width: active ? 12 : warming ? 32 : 54,
              height: 25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xff0b1710),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'SIGNAL EYE',
          style: TextStyle(color: Color(0xffaa8159), fontSize: 7, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

class _VintageAction extends StatelessWidget {
  const _VintageAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool active;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: LinearGradient(
                colors: active
                    ? const [Color(0xffffd58a), Color(0xffa67135)]
                    : const [Color(0xffc8a16b), Color(0xff765333)],
              ),
              border: Border.all(color: const Color(0xff25120c), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: const Color(0xff30170e)),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xff30170e),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Presets extends StatelessWidget {
  const _Presets({
    required this.store,
    required this.currentStation,
    required this.enabled,
    required this.onSelectStation,
  });

  final StationStore store;
  final RadioStation currentStation;
  final bool enabled;
  final Future<void> Function(RadioStation) onSelectStation;

  Future<void> _tap(int index) async {
    final assigned = store.stationById(store.presets[index]);
    if (assigned == null) {
      await store.assignPreset(index, currentStation);
    } else {
      await onSelectStation(assigned);
    }
  }

  @override
  Widget build(BuildContext context) => _InsetPanel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
          child: Column(
            children: [
              const Text(
                'MECHANICAL PRESETS',
                style: TextStyle(color: Color(0xffbb8e5c), fontSize: 8, letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final assigned = store.stationById(store.presets[index]);
                  final active = enabled && assigned?.id == currentStation.id;
                  return GestureDetector(
                    onTap: () => _tap(index),
                    onLongPress: () => store.assignPreset(index, currentStation),
                    onSecondaryTap: () => store.clearPreset(index),
                    child: Tooltip(
                      message: assigned?.name ?? 'Empty preset ${index + 1}',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 42,
                        height: 37,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: active
                                ? const [Color(0xffffe2a0), Color(0xffb77d3c)]
                                : const [Color(0xffd8bd88), Color(0xff80613e)],
                          ),
                          border: Border.all(color: const Color(0xff160a06), width: 2),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xff2d170f),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

class _Dial extends StatelessWidget {
  const _Dial({
    required this.radio,
    required this.lampEnabled,
    required this.stationIndex,
    required this.stationCount,
    required this.movable,
  });

  final RadioPlayer radio;
  final bool lampEnabled;
  final int stationIndex;
  final int stationCount;
  final bool movable;

  double get position {
    if (stationCount <= 1 || stationIndex < 0) return .22;
    return .08 + ((stationIndex / (stationCount - 1)) * .84);
  }

  String get status {
    if (radio.warmingUp) return 'TUBES WARMING';
    return switch (radio.connectionState) {
      RadioConnectionState.off => 'RECEIVER OFF',
      RadioConnectionState.connecting => 'SEEKING SIGNAL',
      RadioConnectionState.playing => 'ON THE AIR',
      RadioConnectionState.error => 'SIGNAL LOST',
    };
  }

  @override
  Widget build(BuildContext context) {
    final illuminated = radio.poweredOn && lampEnabled;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xff25120c),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff140906), width: 5),
      ),
      child: Column(
        children: [
          Expanded(
            child: _MoveArea(
              enabled: movable,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 550),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    colors: illuminated
                        ? const [Color(0xffffdd8a), Color(0xffc88b3b)]
                        : const [Color(0xff796449), Color(0xff44372b)],
                  ),
                  boxShadow: illuminated
                      ? const [BoxShadow(color: Color(0x55ffc85f), blurRadius: 22)]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          radio.station.name,
                          style: TextStyle(
                            color: illuminated ? const Color(0xff402313) : const Color(0xff28231e),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.8,
                          ),
                        ),
                      ),
                      _Scale(illuminated: illuminated, position: position),
                      Text(
                        status,
                        style: TextStyle(
                          color: illuminated ? const Color(0xff4d2a16) : const Color(0xff2b2722),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.1,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              color: illuminated ? const Color(0xff6b3d20) : const Color(0xff302b25),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              !radio.poweredOn
                                  ? '—'
                                  : (radio.nowPlaying ?? 'PROGRAM INFORMATION UNAVAILABLE'),
                              maxLines: 1,
                              style: TextStyle(
                                color: illuminated ? const Color(0xff3d2113) : const Color(0xff211f1c),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            radio.station.id == RadioStation.fogPoint.id
                ? 'DRIFT BAY BROADCASTING SERVICE • THE ONLY RADIO SIGNAL OF DRIFT BAY'
                : (radio.station.subtitle.isEmpty
                    ? 'INTERNET BROADCAST RECEIVER'
                    : radio.station.subtitle),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xffc9a16c), fontSize: 9, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale({required this.illuminated, required this.position});
  final bool illuminated;
  final double position;

  @override
  Widget build(BuildContext context) {
    final alignment = -1 + position.clamp(0.0, 1.0).toDouble() * 2;
    return SizedBox(
      height: 68,
      child: CustomPaint(
        painter: _ScalePainter(illuminated: illuminated),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          alignment: Alignment(alignment, 0),
          child: Container(
            width: 3,
            height: 64,
            decoration: BoxDecoration(
              color: illuminated ? const Color(0xffad1b18) : const Color(0xff453b32),
              boxShadow: illuminated
                  ? const [BoxShadow(color: Color(0x99c71818), blurRadius: 5)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({required this.illuminated});
  final bool illuminated;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = illuminated ? const Color(0xff57321d) : const Color(0xff2f2a25)
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 24; i++) {
      final x = size.width * i / 24;
      final major = i % 6 == 0;
      canvas.drawLine(
        Offset(x, major ? 30 : 39),
        Offset(x, 61),
        paint..strokeWidth = major ? 2 : 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScalePainter oldDelegate) =>
      oldDelegate.illuminated != illuminated;
}

class _ChannelRail extends StatelessWidget {
  const _ChannelRail({
    required this.stations,
    required this.currentStation,
    required this.onSelectStation,
    required this.onOpenDirectory,
  });

  final StationStore stations;
  final RadioStation currentStation;
  final Future<void> Function(RadioStation) onSelectStation;
  final VoidCallback onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xff23110b),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff120806), width: 3),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'CHANNEL MEMORY',
                style: TextStyle(color: Color(0xffc99d67), fontSize: 8, letterSpacing: 1.8),
              ),
              const Spacer(),
              Text(
                '${stations.stations.length} SAVED • MODEL FP-40 • BUILD 0.4.0',
                style: const TextStyle(color: Color(0xff8f6b4c), fontSize: 7, letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stations.stations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final station = stations.stations[index];
                      final active = station.id == currentStation.id;
                      return _ChannelButton(
                        station: station,
                        active: active,
                        onTap: () => onSelectStation(station),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 112,
                  child: _VintageAction(
                    label: 'DIRECTORY / ADD',
                    icon: Icons.add_box_outlined,
                    onTap: onOpenDirectory,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  const _ChannelButton({required this.station, required this.active, required this.onTap});
  final RadioStation station;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 145,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: active
                    ? const [Color(0xffffd78b), Color(0xffa56f35)]
                    : const [Color(0xffb89363), Color(0xff6e4d30)],
              ),
              border: Border.all(color: const Color(0xff160a06), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff2d170f),
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  station.builtIn ? 'FEATURED SIGNAL' : 'CUSTOM CHANNEL',
                  style: const TextStyle(color: Color(0xff50301e), fontSize: 7, letterSpacing: .8),
                ),
              ],
            ),
          ),
        ),
      );
}
