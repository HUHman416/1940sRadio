import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'audio/radio_player.dart';
import 'stations/radio_station.dart';
import 'stations/station_store.dart';

bool get _isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (_isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1080, 680),
      minimumSize: Size(620, 460),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: '1940s Radio',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(Colors.transparent);
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
      theme: ThemeData.dark(useMaterial3: true),
      color: Colors.transparent,
      home: const RadioScreen(),
    );
  }
}

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  late final RadioPlayer radio;
  late final StationStore stations;
  bool _ready = false;

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
    if (_isDesktop) {
      await windowManager.setMovable(!stations.pinned);
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _selectStation(RadioStation station) async {
    await stations.selectStation(station);
    await radio.tuneTo(station);
  }

  Future<void> _togglePin() async {
    final next = !stations.pinned;
    await stations.setPinned(next);
    if (_isDesktop) {
      await windowManager.setMovable(!next);
    }
  }

  Future<void> _showDirectory() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _StationDirectoryDialog(
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
    if (!_ready) {
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
                builder: (context, _) => _RadioCabinet(
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

class _RadioCabinet extends StatelessWidget {
  const _RadioCabinet({
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
          _CabinetHeader(
            pinned: stations.pinned,
            onTogglePin: onTogglePin,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 700;
              final speaker = _MoveArea(
                enabled: !stations.pinned,
                child: const _SpeakerGrille(),
              );
              final dial = _DialPanel(
                radio: radio,
                stationCount: stations.stations.length,
                stationIndex: stations.stations.indexWhere(
                  (station) => station.id == stations.selectedStationId,
                ),
                movable: !stations.pinned,
              );
              return narrow
                  ? Column(children: [speaker, const SizedBox(height: 22), dial])
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
              _Knob(
                label: on ? 'POWER ON' : 'POWER OFF',
                value: on ? .82 : .12,
                onTap: radio.togglePower,
              ),
              _PresetBank(
                store: stations,
                currentStation: radio.station,
                enabled: on,
                onSelectStation: onSelectStation,
              ),
              _Knob(
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
              _VintageButton(
                label: 'STATION DIRECTORY',
                icon: Icons.library_music_outlined,
                onPressed: onOpenDirectory,
              ),
              _MoveArea(
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

class _CabinetHeader extends StatelessWidget {
  const _CabinetHeader({required this.pinned, required this.onTogglePin});

  final bool pinned;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return const SizedBox(height: 4);

    return Row(
      children: [
        _CabinetIconButton(
          tooltip: pinned ? 'Unlock radio position' : 'Lock radio position',
          icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
          active: pinned,
          onPressed: onTogglePin,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MoveArea(
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
        _CabinetIconButton(
          tooltip: 'Minimize',
          icon: Icons.remove,
          onPressed: windowManager.minimize,
        ),
        const SizedBox(width: 6),
        _CabinetIconButton(
          tooltip: 'Close',
          icon: Icons.close,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}

class _CabinetIconButton extends StatelessWidget {
  const _CabinetIconButton({
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
              color: active ? const Color(0xff2a160f) : const Color(0xffd4ad76),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveArea extends StatelessWidget {
  const _MoveArea({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop || !enabled) return child;
    return DragToMoveArea(child: child);
  }
}

class _SpeakerGrille extends StatelessWidget {
  const _SpeakerGrille();

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
          child: CustomPaint(painter: _GrillePainter()),
        ),
      ),
    );
  }
}

class _GrillePainter extends CustomPainter {
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

class _DialPanel extends StatelessWidget {
  const _DialPanel({
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
          _MoveArea(
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
                  _FrequencyScale(on: on, position: dialPosition),
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
          _MoveArea(
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

class _FrequencyScale extends StatelessWidget {
  const _FrequencyScale({required this.on, required this.position});

  final bool on;
  final double position;

  @override
  Widget build(BuildContext context) {
    final alignment = -1.0 + position.clamp(0.0, 1.0) * 2.0;
    return SizedBox(
      height: 70,
      child: CustomPaint(
        painter: _ScalePainter(on: on),
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

class _ScalePainter extends CustomPainter {
  _ScalePainter({required this.on});

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
  bool shouldRepaint(covariant _ScalePainter oldDelegate) => oldDelegate.on != on;
}

class _PresetBank extends StatelessWidget {
  const _PresetBank({
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
                      border: Border.all(color: const Color(0xff26140e), width: 2),
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

class _VintageButton extends StatelessWidget {
  const _VintageButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xffd4b27a), Color(0xff8a643b)],
            ),
            border: Border.all(color: const Color(0xff25130c), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xff2b190f), size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xff2b190f),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 5)),
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

class _StationDirectoryDialog extends StatelessWidget {
  const _StationDirectoryDialog({required this.store, required this.onTune});

  final StationStore store;
  final Future<void> Function(RadioStation station) onTune;

  Future<void> _openEditor(BuildContext context, [RadioStation? station]) async {
    final draft = await showDialog<_StationDraft>(
      context: context,
      builder: (context) => _StationEditorDialog(station: station),
    );
    if (draft == null) return;

    if (station == null) {
      final added = await store.addStation(
        name: draft.name,
        url: draft.url,
        subtitle: draft.subtitle,
      );
      await onTune(added);
    } else {
      await store.updateStation(
        station,
        name: draft.name,
        url: draft.url,
        subtitle: draft.subtitle,
      );
      final updated = store.stationById(station.id);
      if (updated != null && store.selectedStationId == station.id) {
        await onTune(updated);
      }
    }
  }

  Future<void> _remove(BuildContext context, RadioStation station) async {
    final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xff3b2115),
            title: const Text('Remove station?'),
            content: Text('Remove ${station.name} from the directory?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('KEEP'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('REMOVE'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldRemove) return;
    await store.removeStation(station);
    await onTune(store.selectedStation);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xff704026), Color(0xff351b12)],
          ),
          border: Border.all(color: const Color(0xff160b07), width: 4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'STATION DIRECTORY',
                    style: TextStyle(
                      color: Color(0xffffd894),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close directory',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(color: Color(0xff9b7045)),
            Flexible(
              child: AnimatedBuilder(
                animation: store,
                builder: (context, _) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: store.stations.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0x447f5a3c)),
                  itemBuilder: (context, index) {
                    final station = store.stations[index];
                    final selected = station.id == store.selectedStationId;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: Icon(
                        station.builtIn ? Icons.star : Icons.radio,
                        color: selected ? const Color(0xffffd894) : const Color(0xffc49a68),
                      ),
                      title: Text(
                        station.name,
                        style: TextStyle(
                          color: selected ? const Color(0xffffd894) : Colors.white,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        station.subtitle.isEmpty ? station.url : station.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onTune(station),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!station.builtIn)
                            IconButton(
                              tooltip: 'Edit station',
                              onPressed: () => _openEditor(context, station),
                              icon: const Icon(Icons.edit_outlined, size: 19),
                            ),
                          if (!station.builtIn)
                            IconButton(
                              tooltip: 'Remove station',
                              onPressed: () => _remove(context, station),
                              icon: const Icon(Icons.delete_outline, size: 19),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: _VintageButton(
                label: 'ADD STATION',
                icon: Icons.add,
                onPressed: () => _openEditor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationDraft {
  const _StationDraft({required this.name, required this.url, required this.subtitle});

  final String name;
  final String url;
  final String subtitle;
}

class _StationEditorDialog extends StatefulWidget {
  const _StationEditorDialog({this.station});

  final RadioStation? station;

  @override
  State<_StationEditorDialog> createState() => _StationEditorDialogState();
}

class _StationEditorDialogState extends State<_StationEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController urlController;
  late final TextEditingController subtitleController;
  String? error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.station?.name ?? '');
    urlController = TextEditingController(text: widget.station?.url ?? '');
    subtitleController = TextEditingController(text: widget.station?.subtitle ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    subtitleController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    final url = urlController.text.trim();
    final uri = Uri.tryParse(url);
    if (name.isEmpty) {
      setState(() => error = 'Give the station a name.');
      return;
    }
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => error = 'Enter a complete http:// or https:// stream URL.');
      return;
    }
    Navigator.pop(
      context,
      _StationDraft(name: name, url: url, subtitle: subtitleController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff3b2115),
      title: Text(widget.station == null ? 'ADD STATION' : 'EDIT STATION'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Station name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Direct stream URL',
                hintText: 'https://example.com/radio.mp3',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: subtitleController,
              decoration: const InputDecoration(
                labelText: 'Dial subtitle (optional)',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(error!, style: const TextStyle(color: Color(0xffffb4a9))),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _save, child: const Text('SAVE')),
      ],
    );
  }
}
