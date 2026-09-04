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
  static const _alarmDaysKey = 'receiver-alarm-days.v1';
  static const _alarmStationKey = 'receiver-alarm-station.v1';
  static const _alarmVolumeKey = 'receiver-alarm-volume.v1';
  static const _alarmGentleKey = 'receiver-alarm-gentle.v1';
  static const _historyKey = 'receiver-history.v1';
  static const _compactKey = 'receiver-compact.v1';

  Timer? _ticker;
  Future<void> Function()? _onSleepElapsed;
  void Function(double factor)? _onSleepFade;
  Future<void> Function()? _onAlarm;
  bool _loaded = false;
  bool _lampEnabled = true;
  bool _compactMode = false;
  DateTime? _sleepUntil;
  bool _alarmEnabled = false;
  int _alarmHour = 7;
  int _alarmMinute = 0;
  int _alarmDaysMask = 0x7f;
  String? _alarmStationId;
  double _alarmVolume = 55;
  bool _alarmGentle = true;
  String? _lastAlarmDay;
  final List<ListeningHistoryEntry> _history = [];

  bool get loaded => _loaded;
  bool get lampEnabled => _lampEnabled;
  bool get compactMode => _compactMode;
  DateTime? get sleepUntil => _sleepUntil;
  bool get alarmEnabled => _alarmEnabled;
  int get alarmHour => _alarmHour;
  int get alarmMinute => _alarmMinute;
  int get alarmDaysMask => _alarmDaysMask;
  String? get alarmStationId => _alarmStationId;
  double get alarmVolume => _alarmVolume;
  bool get alarmGentle => _alarmGentle;
  List<ListeningHistoryEntry> get history => List.unmodifiable(_history);

  DateTime get fogPointTime => DateTime.now().toUtc().subtract(const Duration(hours: 3));

  Duration? get sleepRemaining {
    final until = _sleepUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get alarmLabel =>
      '${_alarmHour.toString().padLeft(2, '0')}:${_alarmMinute.toString().padLeft(2, '0')}';

  bool alarmRunsOnWeekday(int weekday) {
    final bit = 1 << (weekday - 1);
    return (_alarmDaysMask & bit) != 0;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lampEnabled = prefs.getBool(_lampKey) ?? true;
    _compactMode = prefs.getBool(_compactKey) ?? false;
    final sleepRaw = prefs.getString(_sleepKey);
    final parsedSleep = sleepRaw == null ? null : DateTime.tryParse(sleepRaw);
    if (parsedSleep != null && parsedSleep.isAfter(DateTime.now())) _sleepUntil = parsedSleep;
    _alarmEnabled = prefs.getBool(_alarmEnabledKey) ?? false;
    _alarmHour = prefs.getInt(_alarmHourKey) ?? 7;
    _alarmMinute = prefs.getInt(_alarmMinuteKey) ?? 0;
    _alarmDaysMask = prefs.getInt(_alarmDaysKey) ?? 0x7f;
    _alarmStationId = prefs.getString(_alarmStationKey);
    _alarmVolume = (prefs.getDouble(_alarmVolumeKey) ?? 55).clamp(0, 100).toDouble();
    _alarmGentle = prefs.getBool(_alarmGentleKey) ?? true;
    final rawHistory = prefs.getStringList(_historyKey) ?? const [];
    for (final raw in rawHistory) {
      try {
        _history.add(ListeningHistoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    _loaded = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void bind({
    required Future<void> Function() onSleepElapsed,
    required Future<void> Function() onAlarm,
    void Function(double factor)? onSleepFade,
  }) {
    _onSleepElapsed = onSleepElapsed;
    _onAlarm = onAlarm;
    _onSleepFade = onSleepFade;
  }

  Future<void> setLampEnabled(bool value) async {
    _lampEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lampKey, value);
  }

  Future<void> setCompactMode(bool value) async {
    _compactMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compactKey, value);
  }

  Future<void> setSleepTimer(Duration? duration) async {
    _sleepUntil = duration == null ? null : DateTime.now().add(duration);
    if (duration == null) _onSleepFade?.call(1);
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
    int? daysMask,
    String? stationId,
    double? volume,
    bool? gentle,
  }) async {
    _alarmEnabled = enabled;
    _alarmHour = hour.clamp(0, 23);
    _alarmMinute = minute.clamp(0, 59);
    if (daysMask != null) _alarmDaysMask = daysMask.clamp(1, 0x7f);
    if (stationId != null) _alarmStationId = stationId;
    if (volume != null) _alarmVolume = volume.clamp(0, 100).toDouble();
    if (gentle != null) _alarmGentle = gentle;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmEnabledKey, _alarmEnabled);
    await prefs.setInt(_alarmHourKey, _alarmHour);
    await prefs.setInt(_alarmMinuteKey, _alarmMinute);
    await prefs.setInt(_alarmDaysKey, _alarmDaysMask);
    if (_alarmStationId == null) {
      await prefs.remove(_alarmStationKey);
    } else {
      await prefs.setString(_alarmStationKey, _alarmStationId!);
    }
    await prefs.setDouble(_alarmVolumeKey, _alarmVolume);
    await prefs.setBool(_alarmGentleKey, _alarmGentle);
  }

  Future<void> recordNowPlaying(RadioStation station, String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    if (_history.isNotEmpty &&
        _history.first.stationName == station.name &&
        _history.first.title == clean) return;
    _history.insert(0, ListeningHistoryEntry(stationName: station.name, title: clean, at: DateTime.now()));
    if (_history.length > 50) _history.removeRange(50, _history.length);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _history.map((entry) => jsonEncode(entry.toJson())).toList());
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
    if (sleep != null) {
      final remaining = sleep.difference(now);
      if (!remaining.isNegative && remaining <= const Duration(seconds: 60)) {
        _onSleepFade?.call((remaining.inMilliseconds / 60000).clamp(0.0, 1.0));
      }
      if (!sleep.isAfter(now)) {
        _sleepUntil = null;
        _onSleepFade?.call(1);
        SharedPreferences.getInstance().then((prefs) => prefs.remove(_sleepKey));
        final callback = _onSleepElapsed;
        if (callback != null) unawaited(callback());
      }
    }

    if (_alarmEnabled &&
        alarmRunsOnWeekday(now.weekday) &&
        now.hour == _alarmHour &&
        now.minute == _alarmMinute) {
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
