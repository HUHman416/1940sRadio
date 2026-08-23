import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class IcyNowPlaying {
  const IcyNowPlaying({this.title, this.stationName});
  final String? title;
  final String? stationName;
}

class IcyMetadataProbe {
  static Future<IcyNowPlaying?> fetch(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Icy-MetaData', '1');
      request.headers.set(HttpHeaders.userAgentHeader, '1940sRadio/0.3');
      final response = await request.close().timeout(const Duration(seconds: 8));
      final stationName = response.headers.value('icy-name');
      final interval = int.tryParse(response.headers.value('icy-metaint') ?? '');
      if (interval == null || interval <= 0) {
        return stationName == null ? null : IcyNowPlaying(stationName: stationName);
      }

      final bytes = BytesBuilder(copy: false);
      final iterator = StreamIterator<List<int>>(response);
      final targetFloor = interval + 1;
      while (bytes.length < targetFloor && await iterator.moveNext()) {
        bytes.add(iterator.current);
        if (bytes.length > 1024 * 1024) break;
      }
      var data = bytes.takeBytes();
      if (data.length <= interval) return IcyNowPlaying(stationName: stationName);
      final metadataLength = data[interval] * 16;
      final required = interval + 1 + metadataLength;
      if (required > data.length) {
        final extra = BytesBuilder(copy: false)..add(data);
        while (extra.length < required && await iterator.moveNext()) {
          extra.add(iterator.current);
          if (extra.length > 1024 * 1024) break;
        }
        data = extra.takeBytes();
      }
      if (metadataLength == 0 || data.length < required) {
        return IcyNowPlaying(stationName: stationName);
      }
      final raw = utf8.decode(
        Uint8List.sublistView(data, interval + 1, required),
        allowMalformed: true,
      ).replaceAll('\u0000', '');
      final match = RegExp("StreamTitle='([^']*)'", caseSensitive: false).firstMatch(raw);
      final title = match?.group(1)?.trim();
      return IcyNowPlaying(
        title: title == null || title.isEmpty ? null : title,
        stationName: stationName,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
