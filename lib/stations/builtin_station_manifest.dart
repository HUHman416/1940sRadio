import 'dart:convert';
import 'dart:io';

import 'radio_station.dart';

class BuiltinStationManifest {
  static const remoteUrl =
      'https://raw.githubusercontent.com/HUHman416/1940sRadio/main/packaging/stations.json';

  static Future<List<RadioStation>> fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.getUrl(Uri.parse(remoteUrl));
      request.headers.set(HttpHeaders.userAgentHeader, '1940sRadio/0.5');
      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final raw = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['format'] != 'radio1940s.builtin-stations.v1') return const [];
      final stations = <RadioStation>[];
      for (final item in decoded['stations'] as List<dynamic>? ?? const []) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = map['id'] as String?;
        final name = map['name'] as String?;
        final url = map['url'] as String?;
        if (id == null || name == null || url == null || url.trim().isEmpty) continue;
        stations.add(
          RadioStation(
            id: id,
            name: name,
            url: url,
            subtitle: (map['subtitle'] as String?) ?? '',
            fallbackUrls: (map['fallbackUrls'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(growable: false),
            builtIn: true,
          ),
        );
      }
      return stations;
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }
}
