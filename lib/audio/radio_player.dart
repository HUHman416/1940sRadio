import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../stations/radio_station.dart';
import 'icy_metadata.dart';
import 'radio_atmosphere.dart';
import 'system_media.dart';

enum RadioConnectionState { off, connecting, playing, error }

class RadioPlayer extends ChangeNotifier {
  final Player _player = Player();
  final RadioAtmosphere _atmosphere = RadioAtmosphere();
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<String>? _errorSubscription;
  Timer? _metadataTimer;

  RadioConnectionState _connectionState = RadioConnectionState.off;
  double _volume = 72;
  String? _errorMessage;
  String? _nowPlaying;
  bool _poweredOn = false;
  bool _warmingUp = false;
  RadioStation _station = RadioStation.fogPoint;

  RadioConnectionState get connectionState => _connectionState;
  double get volume => _volume;
  String? get errorMessage => _errorMessage;
  String? get nowPlaying => _nowPlaying;
  bool get poweredOn => _poweredOn;
  bool get warmingUp => _warmingUp;
  RadioStation get station => _station;

  Future<void> initialize({RadioStation? initialStation}) async {
    if (initialStation != null) _station = initialStation;

    _playingSubscription = _player.stream.playing.listen((playing) {
      if (!_poweredOn || _warmingUp) return;
      _connectionState = playing
          ? RadioConnectionState.playing
          : RadioConnectionState.connecting;
      _publishSystemState();
      notifyListeners();
    });

    _errorSubscription = _player.stream.error.listen((message) {
      _errorMessage = message;
      _warmingUp = false;
      _connectionState = RadioConnectionState.error;
      _publishSystemState();
      notifyListeners();
    });

    radioSystemHandler?.bind(
      play: powerOn,
      pause: powerOff,
      stop: powerOff,
    );

    await _player.setVolume(_volume);
    _publishSystemState();
  }

  Future<void> powerOn() async {
    if (_poweredOn) return;
    _poweredOn = true;
    _warmingUp = true;
    _errorMessage = null;
    _connectionState = RadioConnectionState.connecting;
    _publishSystemState();
    notifyListeners();
    unawaited(_atmosphere.playTuningBurst());
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!_poweredOn) return;
    _warmingUp = false;
    await _openCurrentStation();
    _startMetadataPolling();
  }

  Future<void> powerOff() async {
    if (!_poweredOn) return;
    _poweredOn = false;
    _warmingUp = false;
    _metadataTimer?.cancel();
    await _player.stop();
    _connectionState = RadioConnectionState.off;
    _errorMessage = null;
    _publishSystemState();
    notifyListeners();
  }

  Future<void> togglePower() async {
    if (_poweredOn) {
      await powerOff();
    } else {
      await powerOn();
    }
  }

  Future<void> tuneTo(RadioStation station) async {
    _station = station;
    _errorMessage = null;
    _nowPlaying = null;
    _publishSystemState();
    notifyListeners();
    if (_poweredOn) {
      unawaited(_atmosphere.playTuningBurst());
      await _openCurrentStation();
      await _refreshMetadata();
    }
  }

  Future<void> retry() async {
    if (!_poweredOn) return;
    await _openCurrentStation();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 100).toDouble();
    await _player.setVolume(_volume);
    notifyListeners();
  }

  Future<void> _openCurrentStation() async {
    _errorMessage = null;
    _connectionState = RadioConnectionState.connecting;
    _publishSystemState();
    notifyListeners();
    try {
      await _player.open(Media(_station.url), play: true);
      await _refreshMetadata();
    } catch (error) {
      _errorMessage = error.toString();
      _connectionState = RadioConnectionState.error;
      _publishSystemState();
      notifyListeners();
    }
  }

  void _startMetadataPolling() {
    _metadataTimer?.cancel();
    _metadataTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _refreshMetadata(),
    );
  }

  Future<void> _refreshMetadata() async {
    if (!_poweredOn) return;
    final metadata = await IcyMetadataProbe.fetch(_station.url);
    final next = metadata?.title;
    if (next != null && next != _nowPlaying) {
      _nowPlaying = next;
      _publishSystemState();
      notifyListeners();
    }
  }

  void _publishSystemState() {
    radioSystemHandler?.publish(
      station: _station,
      playing: _poweredOn && _connectionState == RadioConnectionState.playing,
      nowPlaying: _nowPlaying,
    );
  }

  @override
  void dispose() {
    _metadataTimer?.cancel();
    _playingSubscription?.cancel();
    _errorSubscription?.cancel();
    _player.dispose();
    unawaited(_atmosphere.dispose());
    super.dispose();
  }
}
