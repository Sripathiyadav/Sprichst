import 'dart:typed_data';

/// Mono samples in [-1, 1] and their rate.
class WavAudio {
  const WavAudio(this.samples, this.sampleRate);
  final Float32List samples;
  final int sampleRate;
}

/// Reads a PCM 16-bit WAV (what the recorder writes), mixing channels to mono.
WavAudio decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw const FormatException('Not a WAV file.');
  }
  var channels = 1;
  var sampleRate = 16000;
  var bits = 16;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    var size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (bits != 16) {
        throw FormatException('Unsupported WAV: $bits-bit samples.');
      }
      // Recorders that stream sometimes leave the size as 0 or too large.
      if (size == 0 || body + size > bytes.length) size = bytes.length - body;
      final frames = size ~/ (2 * channels);
      final samples = Float32List(frames);
      for (var i = 0; i < frames; i++) {
        var sum = 0;
        for (var c = 0; c < channels; c++) {
          sum += data.getInt16(body + (i * channels + c) * 2, Endian.little);
        }
        samples[i] = sum / channels / 32768.0;
      }
      return WavAudio(samples, sampleRate);
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV file has no audio data.');
}

/// Mono float samples to a PCM 16-bit WAV file.
Uint8List encodeWav(Float32List samples, int sampleRate) {
  final out = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * 2, Endian.little);
  out.setUint16(32, 2, Endian.little);
  out.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  out.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final s = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    out.setInt16(44 + i * 2, s, Endian.little);
  }
  return out.buffer.asUint8List();
}
