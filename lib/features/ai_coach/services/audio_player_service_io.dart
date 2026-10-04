import 'package:just_audio/just_audio.dart';

class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource({
    required this.bytes,
    required this.contentType,
  });

  final List<int> bytes;
  final String contentType;

  @override
  Future<StreamAudioResponse> request([
    int? start,
    int? end,
  ]) async {
    start ??= 0;
    end ??= bytes.length;

    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(
        bytes.sublist(start, end),
      ),
      contentType: contentType,
    );
  }
}

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playBytes(
    List<int> bytes, {
    String filename = 'sprichst_speech.wav',
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Speech audio is empty.');
    }

    final source = _BytesAudioSource(
      bytes: bytes,
      contentType: 'audio/wav',
    );

    try {
      await _player.setAudioSource(source);
      await _player.play();
    } on PlayerException catch (e) {
      throw Exception(
        'Audio playback failed '
        '(code: ${e.code}, message: ${e.message})',
      );
    } catch (e) {
      throw Exception('Audio playback failed: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  bool get isPlaying {
    return _player.playing;
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
