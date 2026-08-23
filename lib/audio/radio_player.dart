import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

enum RadioConnectionState { off, connecting, playing, error }

class RadioPlayer extends ChangeNotifier {
  static const fogPointUrl = 'https://streaming.live365.com/a25002';

  final Player _player = Player();
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<String>? _errorSubscription;

  RadioConnectionState _connectionState = RadioConnectionState.off;
  double _volume = 72;
  String? _errorMessage;
  bool _poweredOn = false;

  RadioConnectionState get connectionState => _connectionState;
  double get volume => _volume;
  String? get errorMessage => _errorMessage;
  bool get poweredOn => _poweredOn;

  Future<void> initialize() async {
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
    _errorMessage = null;
    _connectionState = RadioConnectionState.connecting;
    notifyListeners();

    try {
      await _player.open(Media(fogPointUrl), play: true);
    } catch (error) {
      _errorMessage = error.toString();
      _connectionState = RadioConnectionState.error;
      notifyListeners();
    }
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

  Future<void> retry() async {
    if (!_poweredOn) return;
    _errorMessage = null;
    _connectionState = RadioConnectionState.connecting;
    notifyListeners();
    try {
      await _player.open(Media(fogPointUrl), play: true);
    } catch (error) {
      _errorMessage = error.toString();
      _connectionState = RadioConnectionState.error;
      notifyListeners();
    }
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 100).toDouble();
    await _player.setVolume(_volume);
    notifyListeners();
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    _errorSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
