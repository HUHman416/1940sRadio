import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../audio/radio_player.dart';
import '../platform/desktop_window.dart';
import '../stations/radio_station.dart';
import '../stations/station_store.dart';
import 'station_directory_dialog.dart';
import 'vintage_button.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  late final RadioPlayer radio;
  late final StationStore stations;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    radio = RadioPlayer();
    stations = StationStore();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await stations.load();
    await radio.initialize(initialStation: stations.selectedStation);
    if (isDesktopPlatform) {
      await windowManager.setMovable(!stations.pinned);
    }
    if (mounted) setState(() => ready = true);
  }

  Future<void> _selectStation(RadioStation station) async {
    await stations.selectStation(station);
    await radio.tuneTo(station);
  }

  Future<void> _togglePin() async {
    final next = !stations.pinned;
    await stations.setPinned(next);
    if (isDesktopPlatform) {
      await windowManager.setMovable(!next);
    }
  }

  Future<void> _showDirectory() async {
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
    if (!ready) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: AnimatedBuilder(
              animation: radio,
              builder: (context, _) => AnimatedBuilder(
                animation: stations,
                builder: (context, _) => RadioCabinet(
                  radio: radio,
                  stations: stations,
                  onSelectStation: _selectStation,
                  onTogglePin: _togglePin,
                  onOpenDirectory: _showDirectory,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RadioCabinet extends StatelessWidget {
  const RadioCabinet({
    super.key,
    required this.radio,
    required this.stations,
    required this.onSelectStation,
    required this.onTogglePin,
    required this.onOpenDirectory,
  });

  final RadioPlayer radio;
  final StationStore stations;
  final Future<void> Function(RadioStation station) onSelectStation;
  final VoidCallback onTogglePin;
  final VoidCallback onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    final on = radio.poweredOn;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          colors: [Color(0xff8b4828), Color(0xff542818), Color(0xff30160f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xff1c0d08), width: 5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 14)),
        ],
      ),
      child: Column(
        children: [
          CabinetHeader(
            pinned: stations.pinned,
            onTogglePin: onTogglePin,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 700;
              final speaker = MoveArea(
                enabled: !stations.pinned,
                child: const SpeakerGrille(),
              );
              final stationIndex = stations.stations.indexWhere(
                (station) => station.id == stations.selectedStationId,
              );
              final dial = DialPanel(
                radio: radio,
                stationCount: stations.stations.length,
                stationIndex: stationIndex,
                movable: !stations.pinned,
              );
              return narrow
                  ? Column(
                      children: [speaker, const SizedBox(height: 22), dial],
                    )
                  : Row(
                      children: [
                        Expanded(child: speaker),
                        const SizedBox(width: 26),
                        Expanded(child: dial),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 22,
            runSpacing: 18,
            children: [
              RadioKnob(
                label: on ? 'POWER ON' : 'POWER OFF',
                value: on ? .82 : .12,
                onTap: radio.togglePower,
              ),
              PresetBank(
                store: stations,
                currentStation: radio.station,
                enabled: on,
                onSelectStation: onSelectStation,
              ),
              RadioKnob(
                label: 'VOLUME ${radio.volume.round()}',
                value: radio.volume / 100,
                onChanged: (normalized) => radio.setVolume(normalized * 100),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 10,
            children: [
              VintageButton(
                label: 'STATION DIRECTORY',
                icon: Icons.library_music_outlined,
                onPressed: onOpenDirectory,
              ),
              MoveArea(
                enabled: !stations.pinned,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'MODEL FP-40  •  BUILD 0.2.0',
                    style: TextStyle(
                      color: Color(0xffd2aa73),
                      fontSize: 11,
                      letterSpacing: 2.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CabinetHeader extends StatelessWidget {
  const CabinetHeader({
    super.key,
    required this.pinned,
    required this.onTogglePin,
  });

  final bool pinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) return const SizedBox(height: 4);

    return Row(
      children: [
        CabinetIconButton(
          tooltip: pinned ? 'Unlock radio position' : 'Lock radio position',
          icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
          active: pinned,
          onPressed: onTogglePin,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MoveArea(
            enabled: !pinned,
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x221a0c08),
                borderRadius: BorderRadius.circular(12),
              ),
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
        const SizedBox(width: 8),
        CabinetIconButton(
          tooltip: 'Minimize',
          icon: Icons.remove,
          onPressed: windowManager.minimize,
        ),
        const SizedBox(width: 6),
        CabinetIconButton(
          tooltip: 'Close',
          icon: Icons.close,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}

class CabinetIconButton extends StatelessWidget {
  const CabinetIconButton({
    super.key,
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
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xffc59555) : const Color(0xff2a160f),
              border: Border.all(color: const Color(0xff160a06), width: 2),
            ),
            child: Icon(
              icon,
              size: 17,
              color: active
                  ? const Color(0xff2a160f)
                  : const Color(0xffd4ad76),
            ),
          ),
        ),
      ),
    );
  }
}

class MoveArea extends StatelessWidget {
  const MoveArea({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform || !enabled) return child;
    return DragToMoveArea(child: child);
  }
}

class SpeakerGrille extends StatelessWidget {
  const SpeakerGrille({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xff8f724d),
          border: Border.all(color: const Color(0xff26130d), width: 6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: CustomPaint(painter: GrillePainter()),
        ),
      ),
    );
  }
}

class GrillePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = const Color(0x66402e1e)
      ..strokeWidth = 1.2;
    final light = Paint()
      ..color = const Color(0x33715a3c)
      ..strokeWidth = 1.0;
    for (double x = -size.height; x < size.width + size.height; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), dark);
      canvas.drawLine(
        Offset(x + 4, 0),
        Offset(x + size.height + 4, size.height),
        light,
      );
    }
    for (double x = 0; x < size.width + size.height; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), dark);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DialPanel extends StatelessWidget {
  const DialPanel({
    super.key,
    required this.radio,
    required this.stationCount,
    required this.stationIndex,
    required this.movable,
  });

  final RadioPlayer radio;
  final int stationCount;
  final int stationIndex;
  final bool movable;

  String get status {
    switch (radio.connectionState) {
      case RadioConnectionState.off:
        return 'RECEIVER OFF';
      case RadioConnectionState.connecting:
        return 'TUNING ${radio.station.name}…';
      case RadioConnectionState.playing:
        return 'ON THE AIR';
      case RadioConnectionState.error:
        return 'SIGNAL LOST';
    }
  }

  double get dialPosition {
    if (stationCount <= 1 || stationIndex < 0) return .22;
    return .08 + ((stationIndex / (stationCount - 1)) * .84);
  }

  @override
  Widget build(BuildContext context) {
    final on = radio.poweredOn;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff2b170f),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xff1b0d08), width: 5),
        boxShadow: on
            ? const [BoxShadow(color: Color(0x44ffc65b), blurRadius: 24)]
            : null,
      ),
      child: Column(
        children: [
          MoveArea(
            enabled: movable,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: on
                      ? const [Color(0xffffdc89), Color(0xffbd7d35)]
                      : const [Color(0xff66523d), Color(0xff3b3025)],
                ),
              ),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      radio.station.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: on
                            ? const Color(0xff3f2414)
                            : const Color(0xff211d19),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FrequencyScale(on: on, position: dialPosition),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      status,
                      style: TextStyle(
                        color: on
                            ? const Color(0xff4a2a17)
                            : const Color(0xff25211d),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          MoveArea(
            enabled: movable,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                radio.connectionState == RadioConnectionState.error
                    ? 'Unable to receive this station.'
                    : (radio.station.subtitle.isEmpty
                        ? 'INTERNET BROADCAST RECEIVER'
                        : radio.station.subtitle),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffc9a16c),
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          if (radio.connectionState == RadioConnectionState.error)
            TextButton(onPressed: radio.retry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class FrequencyScale extends StatelessWidget {
  const FrequencyScale({
    super.key,
    required this.on,
    required this.position,
  });

  final bool on;
  final double position;

  @override
  Widget build(BuildContext context) {
    final normalized = position.clamp(0.0, 1.0).toDouble();
    final alignment = -1.0 + normalized * 2.0;
    return SizedBox(
      height: 70,
      child: CustomPaint(
        painter: ScalePainter(on: on),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          alignment: Alignment(on ? alignment : -.95, 0),
          child: Container(
            width: 3,
            height: 64,
            color: on ? const Color(0xffa41b1b) : const Color(0xff47392e),
          ),
        ),
      ),
    );
  }
}

class ScalePainter extends CustomPainter {
  ScalePainter({required this.on});

  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = on ? const Color(0xff57321d) : const Color(0xff2b2723)
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 20; i++) {
      final x = size.width * i / 20;
      final top = i % 5 == 0 ? 35.0 : 43.0;
      canvas.drawLine(Offset(x, top), Offset(x, 60), paint);
    }
    const labels = ['55', '70', '90', '120', '160'];
    for (var i = 0; i < labels.length; i++) {
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: paint.color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final desired = size.width * i / 4 - text.width / 2;
      final x = desired.clamp(0.0, size.width - text.width).toDouble();
      text.paint(canvas, Offset(x, 6));
    }
  }

  @override
  bool shouldRepaint(covariant ScalePainter oldDelegate) => oldDelegate.on != on;
}

class PresetBank extends StatelessWidget {
  const PresetBank({
    super.key,
    required this.store,
    required this.currentStation,
    required this.enabled,
    required this.onSelectStation,
  });

  final StationStore store;
  final RadioStation currentStation;
  final bool enabled;
  final Future<void> Function(RadioStation station) onSelectStation;

  Future<void> _activate(int index) async {
    final station = store.stationById(store.presets[index]);
    if (station == null) {
      await store.assignPreset(index, currentStation);
      return;
    }
    await onSelectStation(station);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(6, (index) {
            final station = store.stationById(store.presets[index]);
            final active = enabled && station?.id == currentStation.id;
            return Tooltip(
              message: station == null
                  ? 'Preset ${index + 1}: empty — click to set'
                  : 'Preset ${index + 1}: ${station.name}\nClick to tune • hold to replace',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _activate(index),
                  onLongPress: () => store.assignPreset(index, currentStation),
                  onSecondaryTap: () => store.clearPreset(index),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 36,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: active
                            ? const [Color(0xffffe4a3), Color(0xffb78345)]
                            : const [Color(0xffdac598), Color(0xff8d704a)],
                      ),
                      border: Border.all(
                        color: const Color(0xff26140e),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xff2b1a11),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          station == null ? '—' : '•',
                          style: const TextStyle(
                            color: Color(0xff4a2d1d),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 7),
        const Text(
          'PRESETS  •  TAP TUNE  •  HOLD SET',
          style: TextStyle(
            color: Color(0xffd0aa76),
            fontSize: 9,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class RadioKnob extends StatefulWidget {
  const RadioKnob({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.onTap,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final VoidCallback? onTap;

  @override
  State<RadioKnob> createState() => _RadioKnobState();
}

class _RadioKnobState extends State<RadioKnob> {
  double startValue = 0;
  double startY = 0;

  void _dragStart(DragStartDetails details) {
    startValue = widget.value;
    startY = details.localPosition.dy;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (widget.onChanged == null) return;
    final delta = (startY - details.localPosition.dy) / 130;
    final next = (startValue + delta).clamp(0.0, 1.0).toDouble();
    widget.onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final angle = -math.pi * .72 + widget.value * math.pi * 1.44;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onVerticalDragStart: widget.onChanged == null ? null : _dragStart,
          onVerticalDragUpdate: widget.onChanged == null ? null : _dragUpdate,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xff68462f), Color(0xff1e100b)],
              ),
              border: Border.all(color: const Color(0xff120907), width: 5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xffd6b77c),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xffd0aa76),
            fontSize: 10,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
