import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../stations/radio_station.dart';

RadioSystemHandler? radioSystemHandler;

bool get supportsSystemMediaControls => Platform.isAndroid || Platform.isIOS;

Future<void> initializeSystemMediaControls() async {
  if (!supportsSystemMediaControls) return;
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.music());
  radioSystemHandler = await AudioService.init(
    builder: RadioSystemHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.huhman416.radio1940s.playback',
      androidNotificationChannelName: '1940s Radio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
    ),
  );
}

class RadioSystemHandler extends BaseAudioHandler {
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onStop;

  void bind({
    required Future<void> Function() play,
    required Future<void> Function() pause,
    required Future<void> Function() stop,
  }) {
    onPlay = play;
    onPause = pause;
    onStop = stop;
  }

  void publish({
    required RadioStation station,
    required bool playing,
    String? nowPlaying,
  }) {
    final raw = nowPlaying?.trim();
    String? artist;
    var title = station.name;
    if (raw != null && raw.isNotEmpty) {
      final split = raw.indexOf(' - ');
      if (split > 0) {
        artist = raw.substring(0, split).trim();
        title = raw.substring(split + 3).trim();
      } else {
        title = raw;
      }
    }
    mediaItem.add(MediaItem(
      id: station.url,
      title: title,
      artist: artist,
      album: station.name,
      isLive: true,
    ));
    playbackState.add(PlaybackState(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0],
      playing: playing,
      processingState: AudioProcessingState.ready,
      updatePosition: Duration.zero,
    ));
  }

  @override
  Future<void> play() async {
    final callback = onPlay;
    if (callback != null) await callback();
  }

  @override
  Future<void> pause() async {
    final callback = onPause;
    if (callback != null) await callback();
  }

  @override
  Future<void> stop() async {
    final callback = onStop;
    if (callback != null) await callback();
  }
}
