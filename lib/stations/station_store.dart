import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'builtin_station_manifest.dart';
import 'radio_station.dart';

class StationStore extends ChangeNotifier {
  static const _stationsKey = 'stations.v1';
  static const _presetsKey = 'presets.v1';
  static const _selectedKey = 'selected-station.v1';
  static const _pinnedKey = 'window-pinned.v1';
  static const _favoritesKey = 'favorites.v1';

  final List<RadioStation> _stations = [RadioStation.fogPoint];
  List<String?> _presets = [RadioStation.fogPoint.id, null, null, null, null, null];
  final Set<String> _favorites = {RadioStation.fogPoint.id};
  String _selectedStationId = RadioStation.fogPoint.id;
  bool _pinned = false;
  bool _loaded = false;

  List<RadioStation> get stations => List.unmodifiable(_stations);
  List<RadioStation> get favorites =>
      _stations.where((station) => _favorites.contains(station.id)).toList(growable: false);
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

  bool isFavorite(String stationId) => _favorites.contains(stationId);

  int? presetForStation(String stationId) {
    final index = _presets.indexOf(stationId);
    return index < 0 ? null : index;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final remoteBuiltIns = await BuiltinStationManifest.fetch();
    if (remoteBuiltIns.isNotEmpty) {
      final fogPoint = remoteBuiltIns.where((station) => station.id == RadioStation.fogPoint.id).firstOrNull;
      if (fogPoint != null) _stations[0] = fogPoint;
      for (final station in remoteBuiltIns) {
        if (station.id != RadioStation.fogPoint.id && stationById(station.id) == null) {
          _stations.add(station);
        }
      }
    }

    final rawStations = prefs.getStringList(_stationsKey) ?? const [];
    for (final raw in rawStations) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final station = RadioStation.fromJson(decoded);
        if (station.id != RadioStation.fogPoint.id &&
            station.url.trim().isNotEmpty &&
            stationById(station.id) == null) {
          _stations.add(station);
        }
      } catch (_) {}
    }

    final savedPresets = prefs.getStringList(_presetsKey);
    if (savedPresets != null && savedPresets.length == 6) {
      _presets = savedPresets.map((value) => value.isEmpty ? null : value).toList();
    }
    _presets[0] ??= RadioStation.fogPoint.id;

    final savedFavorites = prefs.getStringList(_favoritesKey);
    if (savedFavorites != null) {
      _favorites
        ..clear()
        ..addAll(savedFavorites.where((id) => stationById(id) != null));
    }
    _favorites.add(RadioStation.fogPoint.id);

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
    _favorites.remove(station.id);
    _presets = _presets.map((id) => id == station.id ? null : id).toList();
    if (_selectedStationId == station.id) _selectedStationId = RadioStation.fogPoint.id;
    await _saveStations();
    await _savePresets();
    await _saveFavorites();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, _selectedStationId);
    notifyListeners();
  }

  Future<void> toggleFavorite(RadioStation station) async {
    if (_favorites.contains(station.id) && station.id != RadioStation.fogPoint.id) {
      _favorites.remove(station.id);
    } else {
      _favorites.add(station.id);
    }
    await _saveFavorites();
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
    _presets[index] = index == 0 ? RadioStation.fogPoint.id : null;
    await _savePresets();
    notifyListeners();
  }

  Future<void> setPinned(bool value) async {
    _pinned = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinnedKey, value);
  }

  String exportConfiguration() {
    final payload = {
      'format': 'radio1940s.receiver.v1',
      'stations': _stations.where((station) => !station.builtIn).map((station) => station.toJson()).toList(),
      'presets': _presets,
      'favorites': _favorites.toList(),
      'selectedStation': _selectedStationId,
      'pinned': _pinned,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importConfiguration(String raw) async {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (decoded['format'] != 'radio1940s.receiver.v1') {
      throw const FormatException('Unsupported receiver configuration.');
    }
    final imported = <RadioStation>[];
    for (final item in (decoded['stations'] as List<dynamic>? ?? const [])) {
      if (item is Map) {
        imported.add(RadioStation.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    _stations
      ..removeWhere((station) => !station.builtIn)
      ..addAll(imported.where((station) => station.id != RadioStation.fogPoint.id));

    final rawPresets = decoded['presets'] as List<dynamic>?;
    if (rawPresets != null && rawPresets.length == 6) {
      _presets = rawPresets.map((value) {
        final id = value as String?;
        return stationById(id) == null ? null : id;
      }).toList();
    }
    _presets[0] ??= RadioStation.fogPoint.id;

    _favorites
      ..clear()
      ..addAll((decoded['favorites'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .where((id) => stationById(id) != null));
    _favorites.add(RadioStation.fogPoint.id);

    final selected = decoded['selectedStation'] as String?;
    _selectedStationId = stationById(selected) == null ? RadioStation.fogPoint.id : selected!;
    _pinned = decoded['pinned'] as bool? ?? _pinned;
    await _saveStations();
    await _savePresets();
    await _saveFavorites();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, _selectedStationId);
    await prefs.setBool(_pinnedKey, _pinned);
    notifyListeners();
  }

  Future<void> _saveStations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _stationsKey,
      _stations.where((station) => !station.builtIn).map((station) => jsonEncode(station.toJson())).toList(),
    );
  }

  Future<void> _savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_presetsKey, _presets.map((id) => id ?? '').toList());
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favorites.toList());
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) return value;
    return null;
  }
}
