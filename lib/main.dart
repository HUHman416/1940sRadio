import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'audio/radio_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    radio = RadioPlayer();
    radio.initialize();
  }

  @override
  void dispose() {
    radio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff17100c),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: AnimatedBuilder(
                animation: radio,
                builder: (context, _) => _RadioCabinet(radio: radio),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioCabinet extends StatelessWidget {
  const _RadioCabinet({required this.radio});

  final RadioPlayer radio;

  @override
  Widget build(BuildContext context) {
    final on = radio.poweredOn;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          colors: [Color(0xff8b4828), Color(0xff542818), Color(0xff30160f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xff1c0d08), width: 5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 16))],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 700;
              final speaker = const _SpeakerGrille();
              final dial = _DialPanel(radio: radio);
              return narrow
                  ? Column(children: [speaker, const SizedBox(height: 22), dial])
                  : Row(children: [Expanded(child: speaker), const SizedBox(width: 26), Expanded(child: dial)]);
            },
          ),
          const SizedBox(height: 26),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 20,
            children: [
              _Knob(
                label: on ? 'POWER ON' : 'POWER OFF',
                value: on ? .82 : .12,
                onTap: radio.togglePower,
              ),
              _PresetBank(enabled: on),
              _Knob(
                label: 'VOLUME ${radio.volume.round()}',
                value: radio.volume / 100,
                onChanged: (normalized) => radio.setVolume(normalized * 100),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'MODEL FP-40  •  BUILD 0.1.0',
            style: TextStyle(color: Color(0xffd2aa73), fontSize: 11, letterSpacing: 2.2),
          ),
        ],
      ),
    );
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

class _DialPanel extends StatelessWidget {
  const _DialPanel({required this.radio});

  final RadioPlayer radio;

  String get status {
    switch (radio.connectionState) {
      case RadioConnectionState.off:
        return 'RECEIVER OFF';
      case RadioConnectionState.connecting:
        return 'TUNING FOG POINT…';
      case RadioConnectionState.playing:
        return 'ON THE AIR';
      case RadioConnectionState.error:
        return 'SIGNAL LOST';
    }
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
        boxShadow: on ? const [BoxShadow(color: Color(0x44ffc65b), blurRadius: 24)] : null,
      ),
      child: Column(
        children: [
          AnimatedContainer(
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
                Text(
                  'FOG POINT RADIO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: on ? const Color(0xff3f2414) : const Color(0xff211d19),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 20),
                _FrequencyScale(on: on),
                const SizedBox(height: 14),
                Text(
                  status,
                  style: TextStyle(
                    color: on ? const Color(0xff4a2a17) : const Color(0xff25211d),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            radio.connectionState == RadioConnectionState.error
                ? 'Unable to receive Fog Point.'
                : 'DRIFT BAY BROADCASTING SERVICE',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffc9a16c), fontSize: 12, letterSpacing: 1.5),
          ),
          if (radio.connectionState == RadioConnectionState.error)
            TextButton(onPressed: radio.retry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _FrequencyScale extends StatelessWidget {
  const _FrequencyScale({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: CustomPaint(
        painter: _ScalePainter(on: on),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 700),
          alignment: on ? const Alignment(-0.56, 0) : const Alignment(-0.95, 0),
          child: Container(width: 3, height: 64, color: on ? const Color(0xffa41b1b) : const Color(0xff47392e)),
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
        text: TextSpan(text: labels[i], style: TextStyle(color: paint.color, fontSize: 12, fontWeight: FontWeight.bold)),
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
  const _PresetBank({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(6, (index) {
            final active = enabled && index == 0;
            return Container(
              width: 34,
              height: 46,
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
              child: Text('${index + 1}', style: const TextStyle(color: Color(0xff2b1a11), fontWeight: FontWeight.bold)),
            );
          }),
        ),
        const SizedBox(height: 7),
        const Text('STATION PRESETS', style: TextStyle(color: Color(0xffd0aa76), fontSize: 10, letterSpacing: 1.3)),
      ],
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
              gradient: const RadialGradient(colors: [Color(0xff68462f), Color(0xff1e100b)]),
              border: Border.all(color: const Color(0xff120907), width: 5),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 5))],
            ),
            child: Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(color: const Color(0xffd6b77c), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label, style: const TextStyle(color: Color(0xffd0aa76), fontSize: 10, letterSpacing: 1.1)),
      ],
    );
  }
}
