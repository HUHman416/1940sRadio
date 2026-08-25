import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stations/radio_station.dart';

class ListeningHistoryEntry {
  const ListeningHistoryEntry({
    required this.stationName,
    required this.title,
    required this.at,
  });

  final String stationName;
  final String title;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'station': stationName,
        'title': title,
        'at': at.toIso8601String(),
      };

  factory ListeningHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ListeningHistoryEntry(
      stationName: (json['station'] as String?) ?? 'UNKNOWN STATION',
      title: (json['title'] as String?) ?? 'UNKNOWN PROGRAM',
      at: DateTime.tryParse((json['at'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class ReceiverFeatures extends ChangeNotifier {
  static const _lampKey = 'receiver-lamp.v1';
  static const _sleepKey = 'receiver-sleep-until.v1';
  static const _alarmEnabledKey = 'receiver-alarm-enabled.v1';
  static const _alarmHourKey = 'receiver-alarm-hour.v1';
  static const _alarmMinuteKey = 'receiver-alarm-minute.v1';
  static const _historyKey = 'receiver-history.v1';

  Timer? _ticker;
  Future<void> Function()? _onSleepElapsed;
  Future<void> Function()? _onAlarm;
  bool _loaded = false;
  bool _lampEnabled = true;
  DateTime? _sleepUntil;
  bool _alarmEnabled = false;
  int _alarmHour = 7;
  int _alarmMinute = 0;
  String? _lastAlarmDay;
  final List<ListeningHistoryEntry> _history = [];

  bool get loaded => _loaded;
  bool get lampEnabled => _lampEnabled;
  DateTime? get sleepUntil => _sleepUntil;
  bool get alarmEnabled => _alarmEnabled;
  int get alarmHour => _alarmHour;
  int get alarmMinute => _alarmMinute;
  List<ListeningHistoryEntry> get history => List.unmodifiable(_history);

  DateTime get fogPointTime =>
      DateTime.now().toUtc().subtract(const Duration(hours: 3));

  Duration? get sleepRemaining {
    final until = _sleepUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get alarmLabel =>
      '${_alarmHour.toString().padLeft(2, '0')}:${_alarmMinute.toString().padLeft(2, '0')}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lampEnabled = prefs.getBool(_lampKey) ?? true;
    final sleepRaw = prefs.getString(_sleepKey);
    final parsedSleep = sleepRaw == null ? null : DateTime.tryParse(sleepRaw);
    if (parsedSleep != null && parsedSleep.isAfter(DateTime.now())) {
      _sleepUntil = parsedSleep;
    }
    _alarmEnabled = prefs.getBool(_alarmEnabledKey) ?? false;
    _alarmHour = prefs.getInt(_alarmHourKey) ?? 7;
    _alarmMinute = prefs.getInt(_alarmMinuteKey) ?? 0;
    final rawHistory = prefs.getStringList(_historyKey) ?? const [];
    for (final raw in rawHistory) {
      try {
        _history.add(
          ListeningHistoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {}
    }
    _loaded = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void bind({
    required Future<void> Function() onSleepElapsed,
    required Future<void> Function() onAlarm,
  }) {
    _onSleepElapsed = onSleepElapsed;
    _onAlarm = onAlarm;
  }

  Future<void> setLampEnabled(bool value) async {
    _lampEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lampKey, value);
  }

  Future<void> setSleepTimer(Duration? duration) async {
    _sleepUntil = duration == null ? null : DateTime.now().add(duration);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (_sleepUntil == null) {
      await prefs.remove(_sleepKey);
    } else {
      await prefs.setString(_sleepKey, _sleepUntil!.toIso8601String());
    }
  }

  Future<void> setAlarm({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    _alarmEnabled = enabled;
    _alarmHour = hour.clamp(0, 23);
    _alarmMinute = minute.clamp(0, 59);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmEnabledKey, _alarmEnabled);
    await prefs.setInt(_alarmHourKey, _alarmHour);
    await prefs.setInt(_alarmMinuteKey, _alarmMinute);
  }

  Future<void> recordNowPlaying(RadioStation station, String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    if (_history.isNotEmpty &&
        _history.first.stationName == station.name &&
        _history.first.title == clean) {
      return;
    }
    _history.insert(
      0,
      ListeningHistoryEntry(
        stationName: station.name,
        title: clean,
        at: DateTime.now(),
      ),
    );
    if (_history.length > 30) {
      _history.removeRange(30, _history.length);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKey,
      _history.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  void _tick() {
    final now = DateTime.now();
    final sleep = _sleepUntil;
    if (sleep != null && !sleep.isAfter(now)) {
      _sleepUntil = null;
      SharedPreferences.getInstance().then((prefs) => prefs.remove(_sleepKey));
      final callback = _onSleepElapsed;
      if (callback != null) unawaited(callback());
    }

    if (_alarmEnabled && now.hour == _alarmHour && now.minute == _alarmMinute) {
      final dayKey = '${now.year}-${now.month}-${now.day}';
      if (_lastAlarmDay != dayKey) {
        _lastAlarmDay = dayKey;
        final callback = _onAlarm;
        if (callback != null) unawaited(callback());
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
