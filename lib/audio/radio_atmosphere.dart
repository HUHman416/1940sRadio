import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class RadioAtmosphere {
  RadioAtmosphere() : _player = AudioPlayer();

  final AudioPlayer _player;
  Uint8List? _staticBurst;

  Future<void> playTuningBurst() async {
    final bytes = _staticBurst ??= _buildStaticBurst();
    try {
      await _player.stop();
      await _player.setVolume(.18);
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Atmosphere must never interfere with receiving a station.
    }
  }

  Future<void> dispose() => _player.dispose();

  Uint8List _buildStaticBurst() {
    const sampleRate = 22050;
    const seconds = .32;
    final sampleCount = (sampleRate * seconds).round();
    final pcm = ByteData(sampleCount * 2);
    final random = math.Random(1940);

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleCount;
      final fade = math.sin(math.pi * t);
      final hiss = (random.nextDouble() * 2 - 1) * .72;
      final crackle = random.nextDouble() > .985
          ? (random.nextDouble() * 2 - 1) * .9
          : 0.0;
      final sample = ((hiss + crackle).clamp(-1.0, 1.0) * fade * 32767).round();
      pcm.setInt16(i * 2, sample, Endian.little);
    }

    final dataLength = pcm.lengthInBytes;
    final out = ByteData(44 + dataLength);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        out.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    out.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little);
    out.setUint16(22, 1, Endian.little);
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, sampleRate * 2, Endian.little);
    out.setUint16(32, 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    out.setUint32(40, dataLength, Endian.little);
    for (var i = 0; i < dataLength; i++) {
      out.setUint8(44 + i, pcm.getUint8(i));
    }
    return out.buffer.asUint8List();
  }
}
