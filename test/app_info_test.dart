import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grou/app_info.dart';

void main() {
  test('versi di kode sama dengan pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.substring('version:'.length).trim(), '$appVersion+$appBuild');
  });
}
