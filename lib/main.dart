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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff17100c),
        fontFamily: 'serif',
      ),
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
    radio = RadioPlayer()..initialize();
  }

  @override
  void dispose() {
    radio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
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
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff7d3f20), Color(0xff4c2415), Color(0xff2f160f)],
        ),
        border: Border.all(color: const Color(0xff1f0f0a), width: 5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 28, offset: Offset(0, 16)),
          BoxShadow(color: Color(0x557f4a28), blurRadius: 3, spreadRadius: 1),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              if (compact) {
                return Column(
                  children: [
                    const _SpeakerGrille(height: 240),
                    const SizedBox(height: 24),
                    _DialPanel(radio: radio),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 5, child: _SpeakerGrille(height: 330)),
                  const SizedBox(width: 28),
                  Expanded(flex: 6, child: _DialPanel(radio: radio)),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          Container(height: 2, color: const Color(0xff24110b)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 22,
            runSpacing: 20,
            alignment: WrapAlignment.spaceEvenly,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Knob(
                label: on ? 'POWER ON' : 'POWER OFF',
                value: on ? .80 : .12,
                onTap: radio.togglePower,
                onChanged: null,
              ),
              _PresetBank(enabled: on),
              _Knob(
                label: 'VOLUME ${radio.volume.round()}',
                value: radio.volume / 100,
                onTap: null,
                onChanged: radio.setVolume,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'MODEL FP-40  •  BUILD 0.1.0',
            style: TextStyle(
              color: Color(0xffc39a62),
              fontSize: 11,
              letterSpacing: 2.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakerGrille extends StatelessWidget {
  const _SpeakerGrille({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff24120c), width: 6),
        color: const Color(0xff9c7a51),
      ),
      padding: const EdgeInsets.all(13),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _GrillePainter(),
          child: Center(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x5523150f), width: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrillePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xff8c704c));
    final dark = Paint()
      ..color = const Color(0x6638291c)
      ..strokeWidth = 1.2;
    final light = Paint()
      ..color = const Color(0x447c5c39)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width + size.height; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), dark);
      canvas.drawLine(Offset(x + 4, 0), Offset(x + size.height + 4, size.height), light);
    }
    for (double x = 0; x < size.width + size.height; x += 8) {
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xff2c180f),
        border: Border.all(color: const Color(0xff1e0f09), width: 5),
        boxShadow: on
            ? const [BoxShadow(color: Color(0x55ffc45c), blurRadius: 22)]
            : const [],
      ),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: on
                    ? const [Color(0xffffd47a), Color(0xffc78639)]
                    : const [Color(0xff655039), Color(0xff392d22)],
              ),
              border: Border.all(color: const Color(0xff17100c), width: 3),
            ),
            child: Column(
              children: [
                Text(
                  'FOG POINT RADIO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: on ? const Color(0xff3a2113) : const Color(0xff1f1b17),
                    fontSize: 25,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 19),
                _FrequencyScale(on: on),
                const SizedBox(height: 18),
                Text(
                  status,
                  style: TextStyle(
                    color: on ? const Color(0xff4c2916) : const Color(0xff24201c),
                    fontSize: 13,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            radio.connectionState == RadioConnectionState.error
                ? 'Unable to receive Fog Point. Tap RETRY.'
                : 'DRIFT BAY BROADCASTING SERVICE',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffcaa774), letterSpacing: 1.7, fontSize: 12),
          ),
          if (radio.connectionState == RadioConnectionState.error) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: radio.retry, child: const Text('RETRY')),
          ],
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
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ScalePainter(on: on))),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            left: on ? 52 : 8,
            top: 2,
            bottom: 2,
            child: Container(width: 3, color: on ? const Color(0xff9e1515) : const Color(0xff45372d)),
          ),
        ],
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
      ..color = on ? const Color(0xff56331e) : const Color(0xff2e2924)
      ..strokeWidth = 1.5;
    const labels = ['55', '70', '90', '120', '160'];
    for (var i = 0; i < 21; i++) {
      final x = size.width * i / 20;
      final tall = i % 5 == 0;
      canvas.drawLine(Offset(x, 30), Offset(x, tall ? 49 : 42), paint);
    }
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(color: paint.color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = size.width * i / 4 - tp.width / 2;
      tp.paint(canvas, Offset(x.clamp(0, size.width - tp.width), 3));
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
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 34,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: active
                      ? const [Color(0xffffdf9a), Color(0xffb88647)]
                      : const [Color(0xffe4d0a2), Color(0xff8f744d)],
                ),
                border: Border.all(color: const Color(0xff25140d), width: 2),
              ),
              child: Text('${index + 1}', style: const TextStyle(color: Color(0xff2d1d13), fontWeight: FontWeight.bold)),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Text('STATION PRESETS', style: TextStyle(color: Color(0xffc39a62), fontSize: 10, letterSpacing: 1.4)),
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
  double? dragStartValue;
  double dragStartY = 0;

  void _start(DragStartDetails details) {
    dragStartValue = widget.value;
    dragStartY = details.localPosition.dy;
  }

  void _update(DragUpdateDetails details) {
    if (widget.onChanged == null || dragStartValue == null) return;
    final delta = (dragStartY - details.localPosition.dy) / 130;
    widget.onChanged!(((dragStartValue! + delta).clamp(0.0, 1.0)) * 100);
  }

  @override
  Widget build(BuildContext context) {
    final angle = -math.pi * .72 + widget.value * math.pi * 1.44;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onVerticalDragStart: widget.onChanged == null ? null : _start,
          onVerticalDragUpdate: widget.onChanged == null ? null : _update,
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xff63412b), Color(0xff1e110c)]),
              border: Border.all(color: const Color(0xff120a07), width: 5),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 5))],
            ),
            child: Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(color: const Color(0xffd5b77d), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label, style: const TextStyle(color: Color(0xffd0ae73), fontSize: 10, letterSpacing: 1.1)),
      ],
    );
  }
}
