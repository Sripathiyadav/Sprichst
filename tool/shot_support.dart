// Shared by the screenshot tools: loads the bundled fonts so text renders
// readably under flutter test.
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadShotFonts() async {
  final figtree = FontLoader('Figtree');
  // Text with no font named (button labels, for one) is drawn with the test
  // font, solid blocks. Giving that font's name to Roboto makes it readable.
  for (final file in Directory('assets/fonts/figtree')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ttf'))) {
    figtree.addFont(Future.value(
        ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
  }
  await figtree.load();
  for (final family in ['Roboto', 'Ahem']) {
    final loader = FontLoader(family);
    for (final file in Directory('assets/fonts/roboto')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ttf'))) {
      loader.addFont(Future.value(
          ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
    }
    await loader.load();
  }

  // Material icons come from the Flutter SDK, which tests do not load alone.
  final root = Platform.environment['FLUTTER_ROOT'] ??
      '/opt/homebrew/Caskroom/flutter/3.24.3/flutter';
  final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(
          ByteData.view(Uint8List.fromList(icons.readAsBytesSync()).buffer)));
    await iconLoader.load();
  }
}
