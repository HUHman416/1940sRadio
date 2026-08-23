import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'radio_station.dart';

class StationStore extends ChangeNotifier {
  static const _stationsKey = 'stations.v1';
  static const _presetsKey = 'presets.v1';
  static const _selectedKey = 'selected-station.v1';
  static const _pinnedKey = 'window-pinned.v1';

  final List<RadioStation> _stations = [RadioStation.fogPoint];
  List<String?> _presets = [RadioStation.fogPoint.id, null, null, null, null, null];
  String _selectedStationId = RadioStation.fogPoint.id;
  bool _pinned = false;
  bool _loaded = false;

  List<RadioStation> get stations => List.unmodifiable(_stations);
  List<String?> get presets => List.unmodifiable(_presets);
  String get selectedStationId => _selectedStationId;
  bool get pinned => _pinned;
  bool get loaded => _loaded;

  RadioStation get selectedStation => stationById(_selectedStationId) ?? RadioStation.fogPoint;

  RadioStation? stationById(String? id) {
    if (id == null) return null;
    for (final station in _stations) {
      if (station.id == id) return station;
    }
    return null;
  }

  int? presetForStation(String stationId) {
    final index = _presets.indexOf(stationId);
    return index < 0 ? null : index;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawStations = prefs.getStringList(_stationsKey) ?? const [];
    for (final raw in rawStations) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final station = RadioStation.fromJson(decoded);
        if (station.id != RadioStation.fogPoint.id && station.url.trim().isNotEmpty) {
          _stations.add(station);
        }
      } catch (_) {
        // Ignore malformed saved stations rather than preventing startup.
      }
    }

    final savedPresets = prefs.getStringList(_presetsKey);
    if (savedPresets != null && savedPresets.length == 6) {
      _presets = savedPresets.map((value) => value.isEmpty ? null : value).toList();
    }
    _presets[0] ??= RadioStation.fogPoint.id;

    final savedSelected = prefs.getString(_selectedKey);
    if (savedSelected != null && stationById(savedSelected) != null) {
      _selectedStationId = savedSelected;
    }
    _pinned = prefs.getBool(_pinnedKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> selectStation(RadioStation station) async {
    _selectedStationId = station.id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, station.id);
  }

  Future<RadioStation> addStation({
    required String name,
    required String url,
    String subtitle = '',
  }) async {
    final station = RadioStation(
      id: 'station-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().toUpperCase(),
      url: url.trim(),
      subtitle: subtitle.trim().toUpperCase(),
    );
    _stations.add(station);
    await _saveStations();
    notifyListeners();
    return station;
  }

  Future<void> updateStation(
    RadioStation station, {
    required String name,
    required String url,
    String subtitle = '',
  }) async {
    if (station.builtIn) return;
    final index = _stations.indexWhere((candidate) => candidate.id == station.id);
    if (index < 0) return;
    _stations[index] = station.copyWith(
      name: name.trim().toUpperCase(),
      url: url.trim(),
      subtitle: subtitle.trim().toUpperCase(),
    );
    await _saveStations();
    notifyListeners();
  }

  Future<void> removeStation(RadioStation station) async {
    if (station.builtIn) return;
    _stations.removeWhere((candidate) => candidate.id == station.id);
    _presets = _presets.map((id) => id == station.id ? null : id).toList();
    if (_selectedStationId == station.id) {
      _selectedStationId = RadioStation.fogPoint.id;
    }
    await _saveStations();
    await _savePresets();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, _selectedStationId);
    notifyListeners();
  }

  Future<void> assignPreset(int index, RadioStation station) async {
    if (index < 0 || index >= 6) return;
    _presets[index] = station.id;
    await _savePresets();
    notifyListeners();
  }

  Future<void> clearPreset(int index) async {
    if (index < 0 || index >= 6) return;
    if (index == 0) {
      _presets[0] = RadioStation.fogPoint.id;
    } else {
      _presets[index] = null;
    }
    await _savePresets();
    notifyListeners();
  }

  Future<void> setPinned(bool value) async {
    _pinned = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinnedKey, value);
  }

  Future<void> _saveStations() async {
    final prefs = await SharedPreferences.getInstance();
    final customStations = _stations.where((station) => !station.builtIn);
    await prefs.setStringList(
      _stationsKey,
      customStations.map((station) => jsonEncode(station.toJson())).toList(),
    );
  }

  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_presetsKey, _presets.map((id) => id ?? '').toList());
  }
}
