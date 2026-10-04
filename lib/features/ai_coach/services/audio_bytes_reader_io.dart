import 'dart:io';

Future<List<int>> readAudioBytes(String path) async {
  final file = File(path);

  if (!await file.exists()) {
    throw Exception('Recorded audio file does not exist.');
  }

  return file.readAsBytes();
}
