import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stations/radio_station.dart';
import 'icy_metadata.dart';
import 'radio_atmosphere.dart';
import 'system_media.dart';

enum RadioConnectionState { off, connecting, playing, error }

enum AtmosphereMode { off, subtle, period }

class RadioPlayer extends ChangeNotifier {
  static const _volumeKey = 'radio-volume.v1';
  static const _atmosphereKey = 'radio-atmosphere.v1';

  final Player _player = Player();
  final RadioAtmosphere _atmosphere = RadioAtmosphere();
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Track>? _trackSubscription;
  Timer? _metadataTimer;
  Timer? _reconnectTimer;

  RadioConnectionState _connectionState = RadioConnectionState.off;
  double _volume = 72;
  String? _errorMessage;
  String? _nowPlaying;
  bool _poweredOn = false;
  bool _warmingUp = false;
  bool _shuttingDown = false;
  int _reconnectAttempt = 0;
  AtmosphereMode _atmosphereMode = AtmosphereMode.subtle;
  RadioStation _station = RadioStation.fogPoint;
  double? _sleepFadeBaseVolume;

  RadioConnectionState get connectionState => _connectionState;
  double get volume => _volume;
  String? get errorMessage => _errorMessage;
  String? get nowPlaying => _nowPlaying;
  bool get poweredOn => _poweredOn;
  bool get warmingUp => _warmingUp;
  bool get shuttingDown => _shuttingDown;
  RadioStation get station => _station;
  AtmosphereMode get atmosphereMode => _atmosphereMode;

  Future<void> initialize({RadioStation? initialStation}) async {
    if (initialStation != null) {
      _station = initialStation;
    }
    final prefs = await SharedPreferences.getInstance();
    _volume = (prefs.getDouble(_volumeKey) ?? 72).clamp(0, 100).toDouble();
    final atmosphereIndex =
        prefs.getInt(_atmosphereKey) ?? AtmosphereMode.subtle.index;
    if (atmosphereIndex >= 0 &&
        atmosphereIndex < AtmosphereMode.values.length) {
      _atmosphereMode = AtmosphereMode.values[atmosphereIndex];
    }

    _playingSubscription = _player.stream.playing.listen((playing) {
      if (!_poweredOn || _warmingUp || _shuttingDown) {
        return;
      }
      _connectionState = playing
          ? RadioConnectionState.playing
          : RadioConnectionState.connecting;
      if (playing) {
        _reconnectAttempt = 0;
      }
      _publishSystemState();
      notifyListeners();
    });

    _trackSubscription = _player.stream.track.listen((track) {
      if (!_poweredOn || _shuttingDown) {
        return;
      }
      final nativeTitle = track.audio.title?.trim();
      if (nativeTitle != null &&
          nativeTitle.isNotEmpty &&
          nativeTitle.toUpperCase() != _station.name.toUpperCase()) {
        _setNowPlaying(nativeTitle);
      }
    });

    _errorSubscription = _player.stream.error.listen((message) {
      if (_shuttingDown) {
        return;
      }
      _errorMessage = message;
      _warmingUp = false;
      _connectionState = RadioConnectionState.error;
      _publishSystemState();
      notifyListeners();
      _scheduleReconnect();
    });

    radioSystemHandler?.bind(play: powerOn, pause: powerOff, stop: powerOff);
    await _player.setVolume(_volume);
    _publishSystemState();
  }

  Future<void> powerOn() async {
    if (_poweredOn || _shuttingDown) {
      return;
    }
    _poweredOn = true;
    _warmingUp = true;
    _errorMessage = null;
    _connectionState = RadioConnectionState.connecting;
    await _syncAtmosphereBed();
    _publishSystemState();
    notifyListeners();
    await _player.setVolume(_volume);
    await _playAtmosphereBurst();
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!_poweredOn || _shuttingDown) {
      return;
    }
    _warmingUp = false;
    await _openCurrentStation();
    _startMetadataPolling();
  }

  Future<void> wakeAtVolume(double target, {required bool gentle}) async {
    final wakeVolume = target.clamp(0, 100).toDouble();
    _volume = wakeVolume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
    if (!gentle) {
      await _player.setVolume(_volume);
      if (!_poweredOn) {
        await powerOn();
      }
      return;
    }

    if (!_poweredOn) {
      await _player.setVolume(0);
      _poweredOn = true;
      _warmingUp = true;
      _connectionState = RadioConnectionState.connecting;
      await _syncAtmosphereBed();
      _publishSystemState();
      notifyListeners();
      await _playAtmosphereBurst();
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (_shuttingDown) {
        return;
      }
      _warmingUp = false;
      await _openCurrentStation();
      _startMetadataPolling();
    }

    for (var step = 1; step <= 20; step++) {
      if (!_poweredOn || _shuttingDown) {
        return;
      }
      await _player.setVolume(wakeVolume * step / 20);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    notifyListeners();
  }

  Future<void> powerOff() async {
    if (!_poweredOn) {
      return;
    }
    _poweredOn = false;
    _warmingUp = false;
    _metadataTimer?.cancel();
    _reconnectTimer?.cancel();
    _sleepFadeBaseVolume = null;
    await _atmosphere.setPeriodBed(false);
    await _player.stop();
    _connectionState = RadioConnectionState.off;
    _errorMessage = null;
    _publishSystemState();
    notifyListeners();
  }

  Future<void> togglePower() => _poweredOn ? powerOff() : powerOn();

  Future<void> tuneTo(RadioStation station) async {
    _station = station;
    _errorMessage = null;
    _nowPlaying = null;
    _reconnectAttempt = 0;
    _publishSystemState();
    notifyListeners();
    if (_poweredOn) {
      await _playAtmosphereBurst();
      await _openCurrentStation();
    }
  }

  Future<bool> testStream(String url) async {
    final probe = Player();
    try {
      await probe
          .open(Media(url), play: false)
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    } finally {
      await probe.dispose();
    }
  }

  Future<void> retry() async {
    if (!_poweredOn || _shuttingDown) {
      return;
    }
    _reconnectTimer?.cancel();
    await _openCurrentStation();
  }

  Future<void> setVolume(double value) async {
    _sleepFadeBaseVolume = null;
    _volume = value.clamp(0, 100).toDouble();
    await _player.setVolume(_volume);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
  }

  void applySleepFade(double factor) {
    if (!_poweredOn || _shuttingDown) {
      return;
    }
    final clamped = factor.clamp(0.0, 1.0).toDouble();
    if (clamped >= .999) {
      final base = _sleepFadeBaseVolume;
      _sleepFadeBaseVolume = null;
      if (base != null) {
        unawaited(_player.setVolume(base));
      }
      return;
    }
    _sleepFadeBaseVolume ??= _volume;
    unawaited(
      _player.setVolume(
        (_sleepFadeBaseVolume! * clamped).clamp(0, 100).toDouble(),
      ),
    );
  }

  Future<void> setAtmosphereMode(AtmosphereMode mode) async {
    _atmosphereMode = mode;
    await _syncAtmosphereBed();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_atmosphereKey, mode.index);
  }

  Future<void> _syncAtmosphereBed() {
    return _atmosphere.setPeriodBed(
      _poweredOn && _atmosphereMode == AtmosphereMode.period,
    );
  }

  Future<void> _playAtmosphereBurst() async {
    if (_atmosphereMode == AtmosphereMode.off) {
      return;
    }
    await _atmosphere.playTuningBurst(
      gain: _atmosphereMode == AtmosphereMode.period ? .26 : .12,
    );
  }

  Future<void> _openCurrentStation() async {
    if (_shuttingDown) {
      return;
    }
    _errorMessage = null;
    _connectionState = RadioConnectionState.connecting;
    _publishSystemState();
    notifyListeners();

    Object? lastError;
    for (final url in _station.playbackUrls) {
      try {
        await _player
            .open(Media(url), play: true)
            .timeout(const Duration(seconds: 12));
        _errorMessage = null;
        await _refreshMetadata(url: url);
        return;
      } catch (error) {
        lastError = error;
      }
    }

    _errorMessage = lastError?.toString() ?? 'No usable stream endpoint.';
    _connectionState = RadioConnectionState.error;
    _publishSystemState();
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_poweredOn ||
        _shuttingDown ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 6).toInt();
    final seconds = (2 << (_reconnectAttempt - 1)).clamp(2, 30).toInt();
    _reconnectTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(_openCurrentStation()),
    );
  }

  void _startMetadataPolling() {
    _metadataTimer?.cancel();
    _metadataTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshMetadata(),
    );
  }

  Future<void> _refreshMetadata({String? url}) async {
    if (!_poweredOn || _shuttingDown) {
      return;
    }
    final metadata = await IcyMetadataProbe.fetch(url ?? _station.url);
    final next = metadata?.title?.trim();
    if (next != null && next.isNotEmpty) {
      _setNowPlaying(next);
    }
  }

  void _setNowPlaying(String title) {
    final clean = title.trim();
    if (clean.isEmpty || clean == _nowPlaying) {
      return;
    }
    _nowPlaying = clean;
    _publishSystemState();
    notifyListeners();
  }

  void _publishSystemState() {
    radioSystemHandler?.publish(
      station: _station,
      playing:
          _poweredOn && _connectionState == RadioConnectionState.playing,
      nowPlaying: _nowPlaying,
    );
  }

  Future<void> shutdown() async {
    if (_shuttingDown) {
      return;
    }
    _shuttingDown = true;
    _poweredOn = false;
    _metadataTimer?.cancel();
    _reconnectTimer?.cancel();
    await _playingSubscription?.cancel();
    await _trackSubscription?.cancel();
    await _errorSubscription?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _atmosphere.setPeriodBed(false);
    } catch (_) {}
    try {
      await _atmosphere.dispose();
    } catch (_) {}
    try {
      await _player.dispose();
    } catch (_) {}
    radioSystemHandler?.bind(
      play: () async {},
      pause: () async {},
      stop: () async {},
    );
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
