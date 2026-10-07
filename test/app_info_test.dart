import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/app_info.dart';

void main() {
  test('AppInfo.version matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':')[1].trim().split('+').first, AppInfo.version);
  });
}
