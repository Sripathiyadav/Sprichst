import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class AudioPlayerService {
  web.HTMLAudioElement? _audio;
  String? _objectUrl;

  Future<void> playBytes(
    List<int> bytes, {
    String filename = 'sprichst_speech.wav',
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Speech audio is empty.');
    }

    await stop();

    try {
      final data = Uint8List.fromList(bytes).buffer.toJS;

      final blob = web.Blob(
        [data].toJS,
        web.BlobPropertyBag(
          type: 'audio/wav',
        ),
      );

      final objectUrl = web.URL.createObjectURL(blob);

      final audio = web.HTMLAudioElement()
        ..src = objectUrl
        ..preload = 'auto';

      _objectUrl = objectUrl;
      _audio = audio;

      await audio.play().toDart;
    } catch (e) {
      await stop();
      throw Exception('Web audio playback failed: $e');
    }
  }

  Future<void> stop() async {
    final audio = _audio;

    if (audio != null) {
      audio.pause();
      audio.currentTime = 0;
    }

    final objectUrl = _objectUrl;

    if (objectUrl != null) {
      web.URL.revokeObjectURL(objectUrl);
    }

    _audio = null;
    _objectUrl = null;
  }

  bool get isPlaying {
    final audio = _audio;
    return audio != null && !audio.paused;
  }

  Future<void> dispose() async {
    await stop();
  }
}
