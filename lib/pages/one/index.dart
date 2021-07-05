import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

// import 'package:flutter_audio_demo/components/seekbar.dart';
class OnePage extends StatefulWidget {
  const OnePage({Key key}) : super(key: key);

  @override
  _OnePageState createState() => _OnePageState();
}

class _OnePageState extends State<OnePage> {
  @override
  void initState() {
    super.initState();
    AudioService.start(
      backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
      androidNotificationChannelName: 'Audio Service Demo',
      // Enable this if you want the Android service to exit the foreground state on pause.
      androidStopForegroundOnPause: true,
      androidNotificationColor: 0xFF2196f3,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidEnableQueue: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('音频')),
      body: Center(
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('音频播放'),
            playButton(),
          ],
        ),
      ),
    );
  }

  IconButton playButton() => IconButton(
        icon: Icon(Icons.play_arrow),
        iconSize: 64.0,
        onPressed: AudioService.play,
      );

  IconButton pauseButton() => IconButton(
        icon: Icon(Icons.pause),
        iconSize: 64.0,
        onPressed: AudioService.pause,
      );

  IconButton stopButton() => IconButton(
        icon: Icon(Icons.stop),
        iconSize: 64.0,
        onPressed: AudioService.stop,
      );
}

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  // final _mediaLibrary = MediaLibrary();
  AudioPlayer _player = new AudioPlayer();
  AudioProcessingState _skipState;
  // Seeker _seeker;
  StreamSubscription<PlaybackEvent> _eventSubscription;

  // List<MediaItem> get queue => _mediaLibrary.items;
  int get index => _player.currentIndex;
  // MediaItem get mediaItem => index == null ? null : queue[index];
  final mediaItem = MediaItem(
    id: "https://mp32.9ku.com/upload/128/2018/02/09/875689.mp3",
    album: "海边",
    title: "夏天海边",
    artUri: "http://p1.music.126.net/0kIhZ79xP169WBrZMyekWw==/109951162856187206.jpg?imageView&thumbnail=360y360&quality=75&tostatic=0",
  );
  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    // We configure the audio session for speech since we're playing a podcast.
    // You can also put this in your app's initialisation if your app doesn't
    // switch between two types of audio as this example does.
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      print('----播放index------$index');
      if (index != null) AudioServiceBackground.setMediaItem(mediaItem);
    });
    // Propagate all events from the audio player to AudioService clients.
    _eventSubscription = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });
    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      switch (state) {
        case ProcessingState.completed:
          // In this example, the service stops when reaching the end.
          onStop();
          break;
        case ProcessingState.ready:
          // If we just came from skipping between tracks, clear the skip
          // state now that we're ready to play.
          _skipState = null;
          break;
        default:
          break;
      }
    });

    // Play when ready.
    _player.play();
    // Start loading something (will play when ready).
    await _player.setUrl(mediaItem.id);

    // Load and broadcast the queue
    // AudioServiceBackground.setQueue(queue);
    // try {
    //   await _player.setAudioSource(ConcatenatingAudioSource(
    //     children: queue.map((item) => AudioSource.uri(Uri.parse(item.id))).toList(),
    //   ));
    //   // In this example, we automatically start playing on start.
    //   onPlay();
    // } catch (e) {
    //   print("Error: $e");
    //   onStop();
    // }
  }

  // @override
  // Future<void> onSkipToQueueItem(String mediaId) async {
  //   // Then default implementations of onSkipToNext and onSkipToPrevious will
  //   // delegate to this method.
  //   final newIndex = queue.indexWhere((item) => item.id == mediaId);
  //   if (newIndex == -1) return;
  //   // During a skip, the player may enter the buffering state. We could just
  //   // propagate that state directly to AudioService clients but AudioService
  //   // has some more specific states we could use for skipping to next and
  //   // previous. This variable holds the preferred state to send instead of
  //   // buffering during a skip, and it is cleared as soon as the player exits
  //   // buffering (see the listener in onStart).
  //   _skipState = newIndex > index ? AudioProcessingState.skippingToNext : AudioProcessingState.skippingToPrevious;
  //   // This jumps to the beginning of the queue item at newIndex.
  //   _player.seek(Duration.zero, index: newIndex);
  //   // Demonstrate custom events.
  //   AudioServiceBackground.sendCustomEvent('skip to $newIndex');
  // }

  @override
  Future<void> onPlay() => _player.play();

  @override
  Future<void> onPause() => _player.pause();

  @override
  Future<void> onSeekTo(Duration position) => _player.seek(position);

  @override
  Future<void> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  // @override
  // Future<void> onSeekForward(bool begin) async => _seekContinuously(begin, 1);

  // @override
  // Future<void> onSeekBackward(bool begin) async => _seekContinuously(begin, -1);

  @override
  Future<void> onStop() async {
    await _player.dispose();
    _eventSubscription.cancel();
    // It is important to wait for this state to be broadcast before we shut
    // down the task. If we don't, the background task will be destroyed before
    // the message gets sent to the UI.
    await _broadcastState();
    // Shut down this task
    await super.onStop();
  }

  /// Jumps away from the current position by [offset].
  Future<void> _seekRelative(Duration offset) async {
    var newPosition = _player.position + offset;
    // Make sure we don't jump out of bounds.
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
    // Perform the jump via a seek.
    await _player.seek(newPosition);
  }

  /// Begins or stops a continuous seek in [direction]. After it begins it will
  /// continue seeking forward or backward by 10 seconds within the audio, at
  /// intervals of 1 second in app time.
  // void _seekContinuously(bool begin, int direction) {
  //   _seeker?.stop();
  //   if (begin) {
  //     _seeker = Seeker(_player, Duration(seconds: 10 * direction), Duration(seconds: 1), mediaItem)..start();
  //   }
  // }

  /// Broadcasts the current state to all clients.
  Future<void> _broadcastState() async {
    await AudioServiceBackground.setState(
      controls: [
        // MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        // MediaControl.skipToNext,
      ],
      systemActions: [
        MediaAction.seekTo,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      ],
      // androidCompactActions: [0, 1, 3],
      // processingState: _getProcessingState(),
      playing: _player.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }
}

/// Provides access to a library of media items. In your app, this could come
/// from a database or web service.
// class MediaLibrary {
//   final _items = <MediaItem>[
//     MediaItem(
//       id: "https://mp3.9ku.com/hot/2005/06-26/66963.mp3",
//       album: "儿歌大全",
//       title: "虫儿飞",
//       artist: "儿童合唱团",
//       duration: Duration(milliseconds: 50000),
//       artUri: "http://p1.music.126.net/0kIhZ79xP169WBrZMyekWw==/109951162856187206.jpg?imageView&thumbnail=360y360&quality=75&tostatic=0",
//     ),
//     MediaItem(
//       id: "https://mp3.9ku.com/hot/2004/07-13/1031.mp3",
//       album: "Science Friday",
//       title: "From Cat Rheology To Operatic Incompetence",
//       artist: "Science Friday and WNYC Studios",
//       duration: Duration(milliseconds: 56950),
//       artUri: "https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg",
//     ),
//   ];

//   List<MediaItem> get items => _items;
// }
