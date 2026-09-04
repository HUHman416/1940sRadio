class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.url,
    this.subtitle = '',
    this.fallbackUrls = const [],
    this.builtIn = false,
  });

  static const fogPoint = RadioStation(
    id: 'fog-point-radio',
    name: 'FOG POINT RADIO',
    url: 'https://s4.radio.co/s3ff272827/listen',
    subtitle: 'DRIFT BAY BROADCASTING SERVICE',
    builtIn: true,
  );

  final String id;
  final String name;
  final String url;
  final String subtitle;
  final List<String> fallbackUrls;
  final bool builtIn;

  List<String> get playbackUrls {
    final seen = <String>{};
    return <String>[url, ...fallbackUrls]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && seen.add(value))
        .toList(growable: false);
  }

  RadioStation copyWith({
    String? name,
    String? url,
    String? subtitle,
    List<String>? fallbackUrls,
  }) {
    return RadioStation(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      subtitle: subtitle ?? this.subtitle,
      fallbackUrls: fallbackUrls ?? this.fallbackUrls,
      builtIn: builtIn,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'subtitle': subtitle,
        if (fallbackUrls.isNotEmpty) 'fallbackUrls': fallbackUrls,
      };

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final fallbacks = (json['fallbackUrls'] as List<dynamic>?)
            ?.whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return RadioStation(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      subtitle: (json['subtitle'] as String?) ?? '',
      fallbackUrls: fallbacks,
    );
  }
}
