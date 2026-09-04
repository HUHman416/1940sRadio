import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class RadioAtmosphere {
  RadioAtmosphere()
      : _burstPlayer = AudioPlayer(),
        _bedPlayer = AudioPlayer();

  final AudioPlayer _burstPlayer;
  final AudioPlayer _bedPlayer;
  Uint8List? _staticBurst;
  Uint8List? _periodBed;
  bool _bedPlaying = false;

  Future<void> playTuningBurst({double gain = .18}) async {
    final bytes = _staticBurst ??= _buildStaticBurst();
    try {
      await _burstPlayer.stop();
      await _burstPlayer.setVolume(gain.clamp(0.0, 1.0));
      await _burstPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Atmosphere must never interfere with receiving a station.
    }
  }

  Future<void> setPeriodBed(bool enabled) async {
    if (enabled == _bedPlaying) {
      return;
    }
    try {
      if (!enabled) {
        _bedPlaying = false;
        await _bedPlayer.stop();
        return;
      }
      final bytes = _periodBed ??= _buildPeriodBed();
      await _bedPlayer.setReleaseMode(ReleaseMode.loop);
      await _bedPlayer.setVolume(.055);
      await _bedPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
      _bedPlaying = true;
    } catch (_) {
      _bedPlaying = false;
      // This layer is deliberately optional; radio playback takes priority.
    }
  }

  Future<void> dispose() async {
    await _burstPlayer.dispose();
    await _bedPlayer.dispose();
  }

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
      final sample =
          ((hiss + crackle).clamp(-1.0, 1.0) * fade * 32767).round();
      pcm.setInt16(i * 2, sample, Endian.little);
    }

    return _waveFromPcm(pcm, sampleRate);
  }

  Uint8List _buildPeriodBed() {
    const sampleRate = 22050;
    const seconds = 4;
    final sampleCount = sampleRate * seconds;
    final pcm = ByteData(sampleCount * 2);
    final random = math.Random(1945);

    var filteredNoise = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final hum = math.sin(2 * math.pi * 60 * t) * .12 +
          math.sin(2 * math.pi * 120 * t) * .045;
      final noise = (random.nextDouble() * 2 - 1);
      filteredNoise = filteredNoise * .84 + noise * .16;
      final hiss = filteredNoise * .12;
      final crackle = random.nextDouble() > .9992
          ? (random.nextDouble() * 2 - 1) * .33
          : 0.0;
      final sample =
          ((hum + hiss + crackle).clamp(-1.0, 1.0) * 32767).round();
      pcm.setInt16(i * 2, sample, Endian.little);
    }

    return _waveFromPcm(pcm, sampleRate);
  }

  Uint8List _waveFromPcm(ByteData pcm, int sampleRate) {
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
