import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Writes the screenshots of the device smoke test into
/// `build/screenshots/<platform>/`.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final directory = Directory(
        'build/screenshots/${Platform.operatingSystem}',
      );
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      File('${directory.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
