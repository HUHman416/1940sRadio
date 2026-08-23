import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../stations/radio_station.dart';

enum RadioConnectionState { off, connecting, playing, error }

class RadioPlayer extends ChangeNotifier {
  final Player _player = Player();
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<String>? _errorSubscription;

  RadioConnectionState _connectionState = RadioConnectionState.off;
  double _volume = 72;
  String? _errorMessage;
  bool _poweredOn = false;
  RadioStation _station = RadioStation.fogPoint;

  RadioConnectionState get connectionState => _connectionState;
  double get volume => _volume;
  String? get errorMessage => _errorMessage;
  bool get poweredOn => _poweredOn;
  RadioStation get station => _station;

  Future<void> initialize({RadioStation? initialStation}) async {
    if (initialStation != null) _station = initialStation;

    _playingSubscription = _player.stream.playing.listen((playing) {
      if (!_poweredOn) return;
      _connectionState = playing
          ? RadioConnectionState.playing
          : RadioConnectionState.connecting;
      notifyListeners();
    });

    _errorSubscription = _player.stream.error.listen((message) {
      _errorMessage = message;
      _connectionState = RadioConnectionState.error;
      notifyListeners();
    });

    await _player.setVolume(_volume);
  }

  Future<void> powerOn() async {
    if (_poweredOn) return;
    _poweredOn = true;
    await _openCurrentStation();
  }

  Future<void> powerOff() async {
    if (!_poweredOn) return;
    _poweredOn = false;
    await _player.stop();
    _connectionState = RadioConnectionState.off;
    _errorMessage = null;
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
    notifyListeners();
    if (_poweredOn) {
      await _openCurrentStation();
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
    notifyListeners();
    try {
      await _player.open(Media(_station.url), play: true);
    } catch (error) {
      _errorMessage = error.toString();
      _connectionState = RadioConnectionState.error;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    _errorSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
