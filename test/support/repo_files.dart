import 'dart:io';

/// The files that are part of the repository: tracked, or new but not ignored.
/// Ignored files (local secrets such as firebase_options.dart, build output,
/// downloaded packages) are deliberately left out, because only what is
/// committed can leak.
List<File> repositoryFiles() {
  final result = Process.runSync(
    'git',
    ['ls-files', '-co', '--exclude-standard', '-z'],
    stdoutEncoding: const SystemEncoding(),
  );
  if (result.exitCode != 0) {
    throw StateError('git ls-files failed: ${result.stderr}');
  }
  return [
    for (final path in (result.stdout as String).split('\u0000'))
      if (path.isNotEmpty && File(path).existsSync()) File(path),
  ];
}

bool isText(File file) {
  const binary = [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.ico',
    '.ttf',
    '.otf',
    '.woff',
    '.woff2',
    '.wasm',
    '.jar',
    '.zip',
    '.mp3',
    '.wav',
    '.onnx',
    '.bin',
    '.gguf',
    '.icns',
    '.pdf',
    '.keystore',
    '.jks',
  ];
  return !binary.any(file.path.toLowerCase().endsWith);
}

/// Reads a text file, or '' if it is not valid UTF-8.
String readText(File file) {
  try {
    return file.readAsStringSync();
  } catch (_) {
    return '';
  }
}
