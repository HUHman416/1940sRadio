import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../audio/radio_player.dart';
import '../platform/desktop_window.dart';
import '../stations/radio_station.dart';
import '../stations/station_store.dart';
import 'station_directory_dialog.dart';
import 'vintage_button.dart';

class RadioScreenV3 extends StatefulWidget {
  const RadioScreenV3({super.key});

  @override
  State<RadioScreenV3> createState() => _RadioScreenV3State();
}

class _RadioScreenV3State extends State<RadioScreenV3> {
  late final RadioPlayer radio = RadioPlayer();
  late final StationStore stations = StationStore();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await stations.load();
      await radio.initialize(initialStation: stations.selectedStation);
    } catch (error, stackTrace) {
      debugPrint('Radio bootstrap warning: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await radio.initialize(initialStation: RadioStation.fogPoint);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => ready = true);
    }
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

  @override
  void dispose() {
    radio.dispose();
    stations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final portrait = constraints.maxHeight > constraints.maxWidth * 1.08;
          final designSize = portrait ? const Size(430, 840) : const Size(1040, 610);
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff8b4828), Color(0xff542818), Color(0xff30160f)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: designSize.width,
                    height: designSize.height,
                    child: ready
                        ? AnimatedBuilder(
                            animation: radio,
                            builder: (context, _) => AnimatedBuilder(
                              animation: stations,
                              builder: (context, _) => _Cabinet(
                                portrait: portrait,
                                radio: radio,
                                stations: stations,
                                onSelectStation: _selectStation,
                                onOpenDirectory: _openDirectory,
                              ),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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
    required this.onSelectStation,
    required this.onOpenDirectory,
  });

  final bool portrait;
  final RadioPlayer radio;
  final StationStore stations;
  final Future<void> Function(RadioStation) onSelectStation;
  final VoidCallback onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    final stationIndex = stations.stations.indexWhere(
      (station) => station.id == stations.selectedStationId,
    );
    final speaker = _MoveArea(
      enabled: !stations.pinned,
      child: const _Speaker(),
    );
    final dial = _Dial(
      radio: radio,
      stationIndex: stationIndex,
      stationCount: stations.stations.length,
      movable: !stations.pinned,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        portrait ? 18 : 26,
        12,
        portrait ? 18 : 26,
        18,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xff1c0d08), width: 5),
        borderRadius: BorderRadius.circular(portrait ? 24 : 32),
        gradient: const LinearGradient(
          colors: [Color(0xff8b4828), Color(0xff542818), Color(0xff30160f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _Header(
            pinned: stations.pinned,
            onTogglePin: () => stations.setPinned(!stations.pinned),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: portrait
                ? Column(
                    children: [
                      Expanded(flex: 4, child: speaker),
                      const SizedBox(height: 14),
                      Expanded(flex: 5, child: dial),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 9, child: speaker),
                      const SizedBox(width: 22),
                      Expanded(flex: 11, child: dial),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _Controls(
            radio: radio,
            stations: stations,
            currentStation: radio.station,
            onSelectStation: onSelectStation,
            onOpenDirectory: onOpenDirectory,
            portrait: portrait,
          ),
        ],
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
      return const Text(
        'FOG POINT RECEIVER • MOBILE SERVICE',
        style: TextStyle(color: Color(0xffd2aa73), fontSize: 9, letterSpacing: 1.7),
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
                    letterSpacing: 1.8,
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
              child: Icon(icon, size: 16, color: const Color(0xffd4ad76)),
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

class _Speaker extends StatelessWidget {
  const _Speaker();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xff8f724d),
          border: Border.all(color: const Color(0xff26130d), width: 6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(painter: _GrillePainter()),
        ),
      );
}

class _GrillePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0x66402e1e)..strokeWidth = 1.2;
    final light = Paint()..color = const Color(0x33715a3c)..strokeWidth = 1.0;
    for (double x = -size.height; x < size.width + size.height; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), dark);
      canvas.drawLine(Offset(x + 4, 0), Offset(x + size.height + 4, size.height), light);
    }
    for (double x = 0; x < size.width + size.height; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), dark);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dial extends StatelessWidget {
  const _Dial({
    required this.radio,
    required this.stationIndex,
    required this.stationCount,
    required this.movable,
  });
  final RadioPlayer radio;
  final int stationIndex;
  final int stationCount;
  final bool movable;

  double get position {
    if (stationCount <= 1 || stationIndex < 0) return .22;
    return .08 + ((stationIndex / (stationCount - 1)) * .84);
  }

  String get status => switch (radio.connectionState) {
        RadioConnectionState.off => 'RECEIVER OFF',
        RadioConnectionState.connecting => 'TUNING…',
        RadioConnectionState.playing => 'ON THE AIR',
        RadioConnectionState.error => 'SIGNAL LOST',
      };

  @override
  Widget build(BuildContext context) {
    final on = radio.poweredOn;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff2b170f),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff1b0d08), width: 5),
      ),
      child: Column(
        children: [
          Expanded(
            child: _MoveArea(
              enabled: movable,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    colors: on
                        ? const [Color(0xffffdc89), Color(0xffbd7d35)]
                        : const [Color(0xff66523d), Color(0xff3b3025)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        radio.station.name,
                        style: TextStyle(
                          color: on ? const Color(0xff3f2414) : const Color(0xff211d19),
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    _Scale(on: on, position: position),
                    Text(
                      status,
                      style: TextStyle(
                        color: on ? const Color(0xff4a2a17) : const Color(0xff25211d),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            color: on ? const Color(0xff5c351d) : const Color(0xff2c2722),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            !on
                                ? '—'
                                : (radio.nowPlaying ?? 'PROGRAM INFORMATION UNAVAILABLE'),
                            maxLines: 1,
                            style: TextStyle(
                              color: on ? const Color(0xff3f2414) : const Color(0xff211d19),
                              fontSize: 12,
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
          const SizedBox(height: 8),
          Text(
            radio.connectionState == RadioConnectionState.error
                ? 'Unable to receive this station.'
                : (radio.station.subtitle.isEmpty
                    ? 'INTERNET BROADCAST RECEIVER'
                    : radio.station.subtitle),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xffc9a16c), fontSize: 10, letterSpacing: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale({required this.on, required this.position});
  final bool on;
  final double position;

  @override
  Widget build(BuildContext context) {
    final alignment = -1 + position.clamp(0.0, 1.0).toDouble() * 2;
    return SizedBox(
      height: 54,
      child: CustomPaint(
        painter: _ScalePainter(on: on),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 600),
          alignment: Alignment(alignment, 0),
          child: Container(
            width: 3,
            height: 50,
            color: on ? const Color(0xffa41b1b) : const Color(0xff47392e),
          ),
        ),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({required this.on});
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = on ? const Color(0xff57321d) : const Color(0xff2b2723)
      ..strokeWidth = 1.4;
    for (var i = 0; i <= 20; i++) {
      final x = size.width * i / 20;
      canvas.drawLine(Offset(x, i % 5 == 0 ? 28 : 34), Offset(x, 48), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScalePainter oldDelegate) => oldDelegate.on != on;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.radio,
    required this.stations,
    required this.currentStation,
    required this.onSelectStation,
    required this.onOpenDirectory,
    required this.portrait,
  });
  final RadioPlayer radio;
  final StationStore stations;
  final RadioStation currentStation;
  final Future<void> Function(RadioStation) onSelectStation;
  final VoidCallback onOpenDirectory;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    final controls = [
      _Knob(
        label: radio.poweredOn ? 'POWER ON' : 'POWER OFF',
        value: radio.poweredOn ? .82 : .12,
        onTap: radio.togglePower,
      ),
      _Presets(
        store: stations,
        currentStation: currentStation,
        enabled: radio.poweredOn,
        onSelectStation: onSelectStation,
      ),
      _Knob(
        label: 'VOLUME ${radio.volume.round()}',
        value: radio.volume / 100,
        onChanged: (value) => radio.setVolume(value * 100),
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: controls,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VintageButton(
              label: portrait ? 'STATIONS' : 'STATION DIRECTORY',
              icon: Icons.library_music_outlined,
              onPressed: onOpenDirectory,
            ),
            const SizedBox(width: 16),
            const Text(
              'MODEL FP-40 • BUILD 0.3.0',
              style: TextStyle(color: Color(0xffd2aa73), fontSize: 9, letterSpacing: 1.7),
            ),
          ],
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (index) {
              final assigned = store.stationById(store.presets[index]);
              final active = enabled && assigned?.id == currentStation.id;
              return GestureDetector(
                onTap: () => _tap(index),
                onLongPress: () => store.assignPreset(index, currentStation),
                onSecondaryTap: () => store.clearPreset(index),
                child: Container(
                  width: 30,
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: active
                          ? const [Color(0xffffe4a3), Color(0xffb78345)]
                          : const [Color(0xffdac598), Color(0xff8d704a)],
                    ),
                    border: Border.all(color: const Color(0xff26140e), width: 2),
                  ),
                  child: Text('${index + 1}', style: const TextStyle(color: Color(0xff2b1a11))),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          const Text('PRESETS', style: TextStyle(color: Color(0xffd0aa76), fontSize: 8, letterSpacing: 1.2)),
        ],
      );
}

class _Knob extends StatefulWidget {
  const _Knob({required this.label, required this.value, this.onChanged, this.onTap});
  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final VoidCallback? onTap;

  @override
  State<_Knob> createState() => _KnobState();
}

class _KnobState extends State<_Knob> {
  double startValue = 0;
  double startY = 0;

  @override
  Widget build(BuildContext context) {
    final angle = -math.pi * .72 + widget.value * math.pi * 1.44;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onVerticalDragStart: widget.onChanged == null
              ? null
              : (details) {
                  startValue = widget.value;
                  startY = details.localPosition.dy;
                },
          onVerticalDragUpdate: widget.onChanged == null
              ? null
              : (details) {
                  final delta = (startY - details.localPosition.dy) / 120;
                  widget.onChanged!((startValue + delta).clamp(0.0, 1.0).toDouble());
                },
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xff68462f), Color(0xff1e100b)]),
              border: Border.all(color: const Color(0xff120907), width: 5),
            ),
            child: Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 4,
                  height: 16,
                  color: const Color(0xffd6b77c),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(widget.label, style: const TextStyle(color: Color(0xffd0aa76), fontSize: 8)),
      ],
    );
  }
}
