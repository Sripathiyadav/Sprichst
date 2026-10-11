import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A fresh file in the temp directory for the next recording. The `record`
/// plugin needs a real path on mobile and desktop; an empty one fails.
Future<String> newRecordingPath() async {
  final directory = await getTemporaryDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  return '${directory.path}/sprichst_recording_$stamp.wav';
}

/// Removes a finished recording so voice clips do not pile up on the device.
Future<void> deleteRecording(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Best effort: a leftover temp file is harmless.
  }
}
